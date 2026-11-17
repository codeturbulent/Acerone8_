#Requires -RunAsAdministrator
<#
  Acer One 8 (T4-82L Gen 2) - unattended environment setup (Windows)

  Usage (from an elevated PowerShell, or right-click > Run with PowerShell as admin):
      powershell -NoProfile -ExecutionPolicy Bypass -File .\setup_windows.ps1

  What it does (no prompts, safe to re-run):
    - Installs Python 3.11 if no suitable Python (3.9-3.12) exists
    - Downloads Android platform-tools (adb / fastboot)
    - Installs UsbDk (USB access layer used by mtkclient on Windows)
    - Stages the Google USB driver and Zadig (Zadig is only a fallback, never launched)
    - Downloads mtkclient (no Git needed), applies mtk_preloader.py patch if present
    - Builds a venv, installs requirements, verifies imports
    - Generates dump_windows.bat (read-only partition dump, both A/B slots)
  Log file: setup.log (next to this script)
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # makes Invoke-WebRequest much faster
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $Root

try { Start-Transcript -Path (Join-Path $Root 'setup.log') -Force | Out-Null } catch {}

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
$PlatformToolsUrl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
$GoogleDriverUrl  = 'https://dl.google.com/android/repository/usb_driver_r13-windows.zip'
$ZadigUrl         = 'https://github.com/pbatard/libwdi/releases/download/v1.5.1/zadig-2.9.exe'
$UsbDkUrl         = 'https://github.com/daynix/UsbDk/releases/download/v1.00-22/UsbDk_1.0.22_x64.msi'
$PythonUrl        = 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe'
# Set to a commit hash to pin mtkclient (recommended once you have a working patch).
$MtkRef           = 'main'
$MtkZipUrl        = "https://github.com/bkerler/mtkclient/archive/$MtkRef.zip"

$Tools    = Join-Path $Root 'tools'
$Drivers  = Join-Path $Tools 'drivers'
$Backup   = Join-Path $Root 'tablet_backup'
$Stock    = Join-Path $Backup 'STOCK_ORIGINALS'
$MtkDir   = Join-Path $Tools 'mtkclient'
$Venv     = Join-Path $MtkDir '.venv'
$VenvPy   = Join-Path $Venv 'Scripts\python.exe'

$Warnings = New-Object System.Collections.Generic.List[string]

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Step($n, $total, $msg) { Write-Host ""; Write-Host "[$n/$total] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  [..]   $msg" -ForegroundColor Gray }
function Warn($msg) { Write-Host "  [warn] $msg" -ForegroundColor Yellow; $script:Warnings.Add($msg) }

function Refresh-EnvPath {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u"
}

function Get-File([string]$Url, [string]$Out) {
    for ($i = 1; $i -le 4; $i++) {
        try {
            if (Test-Path $Out) { Remove-Item $Out -Force }
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out
            if ((Test-Path $Out) -and ((Get-Item $Out).Length -gt 0)) { return }
            throw 'empty download'
        } catch {
            Info "Download attempt $i failed: $($_.Exception.Message)"
            if ($i -eq 4) { throw "Could not download $Url" }
            Start-Sleep -Seconds (3 * $i)
        }
    }
}

function Expand-Clean([string]$Zip, [string]$Dest) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Expand-Archive -Path $Zip -DestinationPath $Dest -Force
    Remove-Item $Zip -Force
}

function Test-PythonExe([string]$Exe) {
    # Accept Python 3.9 - 3.12 only; reject the Microsoft Store stub.
    if (-not $Exe -or -not (Test-Path $Exe)) { return $false }
    if ($Exe -like '*\WindowsApps\*') { return $false }
    try {
        $v = & $Exe -c "import sys;print('%d.%d' % sys.version_info[:2])"
        if ($LASTEXITCODE -ne 0) { return $false }
        $parts = ("$v").Trim().Split('.')
        $maj = [int]$parts[0]; $min = [int]$parts[1]
        return ($maj -eq 3 -and $min -ge 9 -and $min -le 12)
    } catch { return $false }
}

function Find-Python {
    $cands = New-Object System.Collections.Generic.List[string]

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        foreach ($ver in '-3.12', '-3.11', '-3.10', '-3.9') {
            try {
                $p = & $py.Source $ver -c "import sys;print(sys.executable)" 2>$null
                if ($LASTEXITCODE -eq 0 -and $p) { $cands.Add(("$p").Trim()) }
            } catch {}
        }
    }
    foreach ($n in 'python', 'python3') {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { $cands.Add($c.Source) }
    }
    foreach ($v in '312', '311', '310', '39') {
        $cands.Add("$env:ProgramFiles\Python$v\python.exe")
        $cands.Add("$env:LOCALAPPDATA\Programs\Python\Python$v\python.exe")
    }
    foreach ($c in $cands) { if (Test-PythonExe $c) { return $c } }
    return $null
}

$total = 7

# ----------------------------------------------------------------------------
Write-Host "=================================================================="
Write-Host " Acer One 8 - unattended setup"
Write-Host "=================================================================="

# ----------------------------------------------------------------------------
Step 1 $total 'Creating folders'
foreach ($d in @($Tools, $Drivers, $Backup, $Stock)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
Ok 'tools\, tools\drivers\, tablet_backup\STOCK_ORIGINALS\'

# ----------------------------------------------------------------------------
Step 2 $total 'Python 3.9-3.12'
Refresh-EnvPath
$PyExe = Find-Python
if (-not $PyExe) {
    Info 'No suitable Python found, installing Python 3.11 for all users'
    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Info 'Trying winget'
            & winget install -e --id Python.Python.3.11 --scope machine --silent `
                --accept-source-agreements --accept-package-agreements
            Refresh-EnvPath
            if (Find-Python) { $installed = $true }
        } catch { Info "winget failed: $($_.Exception.Message)" }
    }

    if (-not $installed) {
        Info 'Falling back to the official python.org installer'
        $installer = Join-Path $env:TEMP 'python-installer.exe'
        Get-File $PythonUrl $installer
        $p = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList `
            '/quiet', 'InstallAllUsers=1', 'PrependPath=1', 'Include_test=0', 'Include_launcher=1'
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
            throw "Python installer exited with code $($p.ExitCode)"
        }
        Refresh-EnvPath
    }
    $PyExe = Find-Python
}
if (-not $PyExe) { throw 'Python install failed. Install Python 3.11 manually and re-run this script.' }
Ok "Using $PyExe  ($(& $PyExe --version))"

# ----------------------------------------------------------------------------
Step 3 $total 'Android platform-tools (adb / fastboot)'
$AdbExe = Join-Path $Tools 'platform-tools\adb.exe'
if (-not (Test-Path $AdbExe)) {
    $zip = Join-Path $Tools 'platform-tools.zip'
    Get-File $PlatformToolsUrl $zip
    Expand-Clean $zip $Tools
}
if (-not (Test-Path $AdbExe)) { throw 'platform-tools extraction failed' }
Ok 'platform-tools ready'

# ----------------------------------------------------------------------------
Step 4 $total 'USB drivers (UsbDk, Google USB driver, Zadig fallback)'

# UsbDk (non-fatal: mtkclient may still work with another driver)
try {
    $usbdkInstalled = $false
    foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        if (Get-ItemProperty $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'UsbDk*' }) { $usbdkInstalled = $true }
    }
    if ($usbdkInstalled) {
        Ok 'UsbDk already installed'
    } else {
        $msi = Join-Path $env:TEMP 'UsbDk.msi'
        Get-File $UsbDkUrl $msi
        $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /qn /norestart"
        Remove-Item $msi -Force -ErrorAction SilentlyContinue
        if ($p.ExitCode -eq 0)         { Ok 'UsbDk installed' }
        elseif ($p.ExitCode -eq 3010)  { Ok 'UsbDk installed (reboot recommended before first dump)' ; $Warnings.Add('Reboot recommended for UsbDk.') }
        else                           { Warn "UsbDk installer exit code $($p.ExitCode)" }
    }
} catch { Warn "UsbDk step failed: $($_.Exception.Message)" }

# Google USB driver (non-fatal)
try {
    $inf = Join-Path $Drivers 'usb_driver\android_winusb.inf'
    if (-not (Test-Path $inf)) {
        $zip = Join-Path $Tools 'usb_driver.zip'
        Get-File $GoogleDriverUrl $zip
        Expand-Clean $zip $Drivers
    }
    if (Test-Path $inf) {
        & pnputil.exe /add-driver $inf /install | Out-Null
        Ok 'Google USB driver staged'
    } else { Warn 'Google USB driver inf not found after extraction' }
} catch { Warn "Google USB driver step failed: $($_.Exception.Message)" }

# Zadig (download only, never launched)
try {
    $zadig = Join-Path $Tools 'zadig-2.9.exe'
    if (-not (Test-Path $zadig)) { Get-File $ZadigUrl $zadig }
    Ok 'Zadig downloaded (fallback only, not launched)'
} catch { Warn "Zadig download failed: $($_.Exception.Message)" }

# ----------------------------------------------------------------------------
Step 5 $total 'mtkclient'
$MtkEntry = Join-Path $MtkDir 'mtk.py'
if (-not (Test-Path $MtkEntry)) {
    $zip = Join-Path $Tools 'mtkclient.zip'
    $tmp = Join-Path $Tools '_mtk_extract'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Get-File $MtkZipUrl $zip
    Expand-Clean $zip $tmp
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $inner) { throw 'mtkclient archive layout unexpected' }
    if (Test-Path $MtkDir) { Remove-Item $MtkDir -Recurse -Force }
    Move-Item $inner.FullName $MtkDir
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $MtkEntry)) { throw 'mtkclient download failed' }
Ok "mtkclient ready (ref: $MtkRef)"

$PatchSrc = Join-Path $Root 'mtk_preloader.py'
$PatchDst = Join-Path $MtkDir 'mtkclient\Library\mtk_preloader.py'
if (Test-Path $PatchSrc) {
    if (Test-Path $PatchDst) {
        $bak = "$PatchDst.orig"
        if (-not (Test-Path $bak)) { Copy-Item $PatchDst $bak -Force }
    }
    Copy-Item $PatchSrc $PatchDst -Force
    Ok 'Patched mtk_preloader.py applied (original saved as .orig)'
} else {
    Warn 'mtk_preloader.py not found next to this script; patch NOT applied'
}

# ----------------------------------------------------------------------------
Step 6 $total 'Python virtual environment and dependencies'
if (-not (Test-Path $VenvPy)) {
    & $PyExe -m venv $Venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $VenvPy)) { throw 'venv creation failed' }
}
& $VenvPy -m pip install --upgrade pip setuptools wheel --quiet --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { Warn 'pip self-upgrade failed, continuing' }

$req = Join-Path $MtkDir 'requirements.txt'
$reqOk = $false
if (Test-Path $req) {
    Info 'Installing mtkclient requirements.txt (can take a few minutes)'
    & $VenvPy -m pip install --quiet --disable-pip-version-check -r $req
    if ($LASTEXITCODE -eq 0) { $reqOk = $true }
    else { Warn 'requirements.txt install failed, trying core packages only' }
}
if (-not $reqOk) {
    & $VenvPy -m pip install --quiet --disable-pip-version-check `
        pycryptodomex pyusb pyserial colorama pyfdt fusepy capstone keystone-engine
    if ($LASTEXITCODE -ne 0) { throw 'Failed to install Python dependencies' }
}

$check = "import usb.core, serial, colorama; from Cryptodome.Cipher import AES; print('OK')"
$res = & $VenvPy -c $check
if (("$res").Trim() -ne 'OK') { throw 'Dependency verification failed' }
Ok 'Dependencies installed and verified'

# ----------------------------------------------------------------------------
Step 7 $total 'Generating dump_windows.bat'
$bat = @'
@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo  MediaTek read-only partition dump (slots A and B)
echo  1. Power the tablet completely OFF.
echo  2. Hold Volume Up + Volume Down (not Power).
echo  3. Plug in the USB cable while holding both buttons.
echo ==========================================================

if not exist tablet_backup mkdir tablet_backup
if not exist tablet_backup\STOCK_ORIGINALS mkdir tablet_backup\STOCK_ORIGINALS

tools\mtkclient\.venv\Scripts\python.exe tools\mtkclient\mtk.py r "boot_a,boot_b,init_boot_a,init_boot_b,vbmeta_a,vbmeta_b" "tablet_backup\boot_a.img,tablet_backup\boot_b.img,tablet_backup\init_boot_a.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_a.img,tablet_backup\vbmeta_b.img" --skipwdt
if errorlevel 1 (
    echo.
    echo Dump failed. Check the cable, button combo and driver, then retry.
    pause
    exit /b 1
)

REM Copy to STOCK_ORIGINALS without overwriting anything already there.
for %%f in (tablet_backup\*.img) do (
    if not exist "tablet_backup\STOCK_ORIGINALS\%%~nxf" copy "%%f" "tablet_backup\STOCK_ORIGINALS\" >nul
)

echo.
echo ==========================================================
echo  Done. Stock copies are in tablet_backup\STOCK_ORIGINALS\
echo ==========================================================
pause
'@
Set-Content -Path (Join-Path $Root 'dump_windows.bat') -Value $bat -Encoding ASCII -Force
Ok 'dump_windows.bat written'

# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "=================================================================="
Write-Host " Setup complete"
Write-Host "=================================================================="
if ($Warnings.Count -gt 0) {
    Write-Host " Warnings:" -ForegroundColor Yellow
    foreach ($w in $Warnings) { Write-Host "   - $w" -ForegroundColor Yellow }
}
Write-Host " Next: run dump_windows.bat, then connect the tablet in BROM mode."
Write-Host " Log: $(Join-Path $Root 'setup.log')"

try { Stop-Transcript | Out-Null } catch {}
exit 0
