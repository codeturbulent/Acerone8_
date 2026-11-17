#Requires -RunAsAdministrator
<#
  Acer One 8 (T4-82L Gen 2) - unattended setup, v2 (hang-proof)

  Usage (elevated PowerShell):
      powershell -NoProfile -ExecutionPolicy Bypass -File .\setup_windows.ps1

  Differences from v1:
    - Every external process has a hard timeout and is killed if it stalls
    - pip output is visible (no silent multi-minute waits)
    - pip prefers prebuilt wheels and skips the huge PySide6 GUI package
    - Downloads use curl.exe with stall detection
    - Console QuickEdit is disabled (clicking the window can freeze a script)
    - Zip extraction uses .NET (Expand-Archive is extremely slow on Windows PowerShell 5.1)
    - python.org installer first, winget only as a fallback
    - No driver-staging step that can pop a hidden Windows Security dialog
  Log: setup.log next to this script.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:PIP_NO_INPUT = '1'
$env:PIP_DISABLE_PIP_VERSION_CHECK = '1'
$env:PYTHONUTF8 = '1'

$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $Root
try { Start-Transcript -Path (Join-Path $Root 'setup.log') -Force | Out-Null } catch {}

# Stop a click in the console window from pausing the script.
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleMode {
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int h);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    public static void DisableQuickEdit() {
        IntPtr h = GetStdHandle(-10); uint m;
        if (GetConsoleMode(h, out m)) { m &= ~0x40u; m |= 0x80u; SetConsoleMode(h, m); }
    }
}
'@
    [ConsoleMode]::DisableQuickEdit()
} catch {}

Add-Type -AssemblyName System.IO.Compression.FileSystem

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
$PlatformToolsUrl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
$GoogleDriverUrl  = 'https://dl.google.com/android/repository/usb_driver_r13-windows.zip'
$ZadigUrl         = 'https://github.com/pbatard/libwdi/releases/download/v1.5.1/zadig-2.9.exe'
$UsbDkUrl         = 'https://github.com/daynix/UsbDk/releases/download/v1.00-22/UsbDk_1.0.22_x64.msi'
$PythonUrl        = 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe'
$MagiskUrl        = 'https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk'
$MtkRef           = 'main'      # set to a commit hash to pin
$MtkZipUrl        = "https://github.com/bkerler/mtkclient/archive/$MtkRef.zip"
$InstallGui       = $false      # PySide6 is large and not needed for the CLI

$Tools   = Join-Path $Root 'tools'
$Drivers = Join-Path $Tools 'drivers'
$Backup  = Join-Path $Root 'tablet_backup'
$Stock   = Join-Path $Backup 'STOCK_ORIGINALS'
$MtkDir  = Join-Path $Tools 'mtkclient'
$Venv    = Join-Path $MtkDir '.venv'
$VenvPy  = Join-Path $Venv 'Scripts\python.exe'
$Warnings = New-Object System.Collections.Generic.List[string]
$script:StepName = 'startup'

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Step($n, $total, $msg) {
    $script:StepName = $msg
    Write-Host ""
    Write-Host ("[{0}/{1}] {2}  ({3})" -f $n, $total, $msg, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan
}
function Ok($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Info($m) { Write-Host "  [..]   $m" -ForegroundColor Gray }
function Warn($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow; $script:Warnings.Add($m) }

function Refresh-EnvPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
}

# Run a process with a hard timeout. Kills the whole process tree on timeout.
function Invoke-Proc([string]$File, [string]$ArgLine, [int]$TimeoutSec, [string]$Label) {
    Info "$Label (timeout ${TimeoutSec}s)"
    $p = Start-Process -FilePath $File -ArgumentList $ArgLine -PassThru -NoNewWindow
    $null = $p.Handle   # cache handle so ExitCode is readable after WaitForExit(ms)
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        & taskkill.exe /PID $p.Id /T /F | Out-Null
        throw "$Label timed out after ${TimeoutSec}s"
    }
    return $p.ExitCode
}

function Get-File([string]$Url, [string]$Out, [int]$MaxSec = 900) {
    Info "Downloading $Url"
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    for ($i = 1; $i -le 3; $i++) {
        try {
            if (Test-Path $Out) { Remove-Item $Out -Force }
            $downloaded = $false
            if (Test-Path $curl) {
                try {
                    & $curl -L --ssl-no-revoke --fail -sS --retry 2 --connect-timeout 20 --max-time $MaxSec `
                        --speed-limit 2000 --speed-time 60 -o $Out $Url
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $Out) -and ((Get-Item $Out).Length -gt 0)) {
                        $downloaded = $true
                    }
                } catch {
                    Info "curl failed, attempting Invoke-WebRequest fallback..."
                }
            }
            if (-not $downloaded) {
                Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out -TimeoutSec 300
                if ((Test-Path $Out) -and ((Get-Item $Out).Length -gt 0)) {
                    $downloaded = $true
                }
            }
            if ($downloaded) { return }
            throw 'empty download'
        } catch {
            Info "Attempt $i failed: $($_.Exception.Message)"
            if ($i -eq 3) { throw "Could not download $Url (check internet, proxy or firewall)" }
            Start-Sleep -Seconds (3 * $i)
        }
    }
}

# Extract a zip into $Dest, replacing existing entries with the same names.
function Expand-Zip([string]$Zip, [string]$Dest) {
    $tmp = Join-Path $Tools ('_x_' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $tmp)
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
        Get-ChildItem $tmp | ForEach-Object {
            $target = Join-Path $Dest $_.Name
            if (Test-Path $target) { Remove-Item $target -Recurse -Force }
            Move-Item $_.FullName $target
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $Zip -Force -ErrorAction SilentlyContinue
    }
}

function Test-PythonExe([string]$Exe) {
    if (-not $Exe -or -not (Test-Path $Exe)) { return $false }
    if ($Exe -like '*\WindowsApps\*') { return $false }   # Store stub
    try {
        $v = & $Exe -c "import sys;print('%d.%d' % sys.version_info[:2])"
        if ($LASTEXITCODE -ne 0) { return $false }
        $a = ("$v").Trim().Split('.')
        return ([int]$a[0] -eq 3 -and [int]$a[1] -ge 9 -and [int]$a[1] -le 12)
    } catch { return $false }
}

function Find-Python {
    $c = New-Object System.Collections.Generic.List[string]
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        foreach ($v in '-3.12','-3.11','-3.10','-3.9') {
            try {
                $p = & $py.Source $v -c "import sys;print(sys.executable)" 2>$null
                if ($LASTEXITCODE -eq 0 -and $p) { $c.Add(("$p").Trim()) }
            } catch {}
        }
    }
    foreach ($n in 'python','python3') {
        $x = Get-Command $n -ErrorAction SilentlyContinue
        if ($x) { $c.Add($x.Source) }
    }
    foreach ($v in '312','311','310','39') {
        $c.Add("$env:ProgramFiles\Python$v\python.exe")
        $c.Add("$env:LOCALAPPDATA\Programs\Python\Python$v\python.exe")
    }
    foreach ($x in $c) { if (Test-PythonExe $x) { return $x } }
    return $null
}

$total = 8

try {
    Write-Host "=================================================================="
    Write-Host " Acer One 8 - unattended setup v2"
    Write-Host "=================================================================="

    # ------------------------------------------------------------------------
    Step 1 $total 'Preflight (folders, network)'
    foreach ($d in @($Tools, $Drivers, $Backup, $Stock)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    $curlExe = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path $curlExe) {
        foreach ($h in 'https://dl.google.com','https://github.com','https://www.python.org') {
            & $curlExe -sS -I --max-time 15 -o NUL $h
            if ($LASTEXITCODE -ne 0) { throw "Cannot reach $h. Check internet, proxy, VPN or firewall." }
        }
    }
    Ok 'Folders created, network reachable'

    # ------------------------------------------------------------------------
    Step 2 $total 'Python 3.9-3.12'
    Refresh-EnvPath
    $PyExe = Find-Python
    if (-not $PyExe) {
        Info 'No suitable Python found, installing Python 3.11 for all users'
        $installer = Join-Path $env:TEMP 'python-3.11.9-amd64.exe'
        $done = $false
        try {
            Get-File $PythonUrl $installer 600
            $code = Invoke-Proc $installer '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1' 900 'python.org installer'
            if ($code -eq 0 -or $code -eq 3010) { $done = $true } else { Info "Installer exit code $code" }
        } catch { Info "python.org path failed: $($_.Exception.Message)" }
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        Refresh-EnvPath
        if (-not $done -and (Get-Command winget -ErrorAction SilentlyContinue)) {
            try {
                $null = Invoke-Proc 'winget' 'install -e --id Python.Python.3.11 --scope machine --silent --disable-interactivity --accept-source-agreements --accept-package-agreements' 900 'winget Python'
            } catch { Info "winget failed: $($_.Exception.Message)" }
            Refresh-EnvPath
        }
        $PyExe = Find-Python
    }
    if (-not $PyExe) { throw 'Python install failed. Install Python 3.11 manually and re-run.' }
    Ok "Using $PyExe ($(& $PyExe --version))"

    # ------------------------------------------------------------------------
    Step 3 $total 'Android platform-tools'
    $AdbExe = Join-Path $Tools 'platform-tools\adb.exe'
    if (-not (Test-Path $AdbExe)) {
        $zip = Join-Path $Tools 'platform-tools.zip'
        Get-File $PlatformToolsUrl $zip
        Expand-Zip $zip $Tools
    }
    if (-not (Test-Path $AdbExe)) { throw 'platform-tools extraction failed' }
    Ok 'adb and fastboot ready'

    # ------------------------------------------------------------------------
    Step 4 $total 'USB drivers'
    try {
        $have = $false
        foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
            if (Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'UsbDk*' }) { $have = $true }
        }
        if ($have) { Ok 'UsbDk already installed' }
        else {
            $msi = Join-Path $env:TEMP 'UsbDk.msi'
            Get-File $UsbDkUrl $msi 300
            $code = Invoke-Proc 'msiexec.exe' "/i `"$msi`" /qn /norestart /L*v `"$Root\usbdk_install.log`"" 300 'UsbDk installer'
            Remove-Item $msi -Force -ErrorAction SilentlyContinue
            if ($code -eq 0)        { Ok 'UsbDk installed' }
            elseif ($code -eq 3010) { Ok 'UsbDk installed'; $Warnings.Add('Reboot recommended before the first dump (UsbDk).') }
            else                    { Warn "UsbDk installer exit code $code (see usbdk_install.log)" }
        }
    } catch { Warn "UsbDk step: $($_.Exception.Message)" }

    try {
        $inf = Join-Path $Drivers 'usb_driver\android_winusb.inf'
        if (-not (Test-Path $inf)) {
            $zip = Join-Path $Tools 'usb_driver.zip'
            Get-File $GoogleDriverUrl $zip 300
            Expand-Zip $zip $Drivers
        }
        Ok 'Google USB driver extracted (not installed; only needed for adb on some PCs)'
    } catch { Warn "Google USB driver: $($_.Exception.Message)" }

    try {
        $zadig = Join-Path $Tools 'zadig-2.9.exe'
        if (-not (Test-Path $zadig)) { Get-File $ZadigUrl $zadig 300 }
        Ok 'Zadig downloaded (fallback only)'
    } catch { Warn "Zadig: $($_.Exception.Message)" }

    # ------------------------------------------------------------------------
    Step 5 $total 'mtkclient'
    $MtkEntry = Join-Path $MtkDir 'mtk.py'
    if (-not (Test-Path $MtkEntry)) {
        $zip = Join-Path $Tools 'mtkclient.zip'
        $tmp = Join-Path $Tools '_mtk_extract'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Get-File $MtkZipUrl $zip 600
        Expand-Zip $zip $tmp
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
        if ((Test-Path $PatchDst) -and -not (Test-Path "$PatchDst.orig")) { Copy-Item $PatchDst "$PatchDst.orig" -Force }
        Copy-Item $PatchSrc $PatchDst -Force
        Ok 'Patched mtk_preloader.py applied (original saved as .orig)'
    } else {
        Warn 'mtk_preloader.py not found next to this script; patch NOT applied'
    }

    # ------------------------------------------------------------------------
    Step 6 $total 'Python venv and dependencies'
    if (-not (Test-Path $VenvPy)) {
        $code = Invoke-Proc $PyExe "-m venv `"$Venv`"" 180 'Create venv'
        if ($code -ne 0 -or -not (Test-Path $VenvPy)) { throw 'venv creation failed' }
    }
    $null = Invoke-Proc $VenvPy '-m pip install --upgrade pip setuptools wheel --progress-bar off' 300 'Upgrade pip'

    $req = Join-Path $MtkDir 'requirements.txt'
    $reqOk = $false
    if (Test-Path $req) {
        $reqUse = Join-Path $MtkDir 'requirements.setup.txt'
        $lines = Get-Content $req
        if (-not $InstallGui) { $lines = $lines | Where-Object { $_ -notmatch '^\s*(pyside6|shiboken6)' } }
        Set-Content -Path $reqUse -Value $lines -Encoding ASCII
        try {
            $code = Invoke-Proc $VenvPy "-m pip install --prefer-binary --progress-bar off -r `"$reqUse`"" 1200 'pip install requirements'
            if ($code -eq 0) { $reqOk = $true } else { Warn "requirements install exit code $code, trying core packages" }
        } catch { Warn "requirements install: $($_.Exception.Message); trying core packages" }
    }
    if (-not $reqOk) {
        foreach ($pkg in 'pycryptodomex','pyusb','pyserial','colorama') {
            $code = Invoke-Proc $VenvPy "-m pip install --prefer-binary --progress-bar off $pkg" 300 "pip $pkg"
            if ($code -ne 0) { throw "Required package failed: $pkg" }
        }
        foreach ($pkg in 'pyfdt','fusepy','capstone','keystone-engine') {
            try { $null = Invoke-Proc $VenvPy "-m pip install --prefer-binary --progress-bar off $pkg" 300 "pip $pkg (optional)" } catch { Warn "Optional package skipped: $pkg" }
        }
    }
    $res = & $VenvPy -c "import usb.core, serial, colorama; from Cryptodome.Cipher import AES; print('OK')"
    if (("$res").Trim() -ne 'OK') { throw 'Dependency verification failed' }
    Ok 'Dependencies installed and verified'

    # ------------------------------------------------------------------------
    Step 7 $total 'Magisk v31+ root package'
    $MagiskApk = Join-Path $Backup 'Magisk.apk'
    try {
        if (-not (Test-Path $MagiskApk) -or ((Get-Item $MagiskApk).Length -eq 0)) {
            Get-File $MagiskUrl $MagiskApk 300
        }
        if ((Test-Path $MagiskApk) -and ((Get-Item $MagiskApk).Length -gt 0)) {
            Ok 'Magisk v31.1 APK ready in tablet_backup\Magisk.apk'
        } else {
            Warn 'Magisk APK download was empty (can be downloaded manually to tablet_backup\Magisk.apk)'
        }
    } catch {
        Warn "Magisk APK download: $($_.Exception.Message)"
    }

    # ------------------------------------------------------------------------
    Step 8 $total 'Generating dump_windows.bat'
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

for %%f in (tablet_backup\*.img) do (
    if not exist "tablet_backup\STOCK_ORIGINALS\%%~nxf" copy "%%f" "tablet_backup\STOCK_ORIGINALS\" >nul
)

echo.
echo Done. Stock copies are in tablet_backup\STOCK_ORIGINALS\
pause
'@
    Set-Content -Path (Join-Path $Root 'dump_windows.bat') -Value $bat -Encoding ASCII -Force
    Ok 'dump_windows.bat written'

    Write-Host ""
    Write-Host "=================================================================="
    Write-Host " Setup complete"
    Write-Host "=================================================================="
    if ($Warnings.Count -gt 0) {
        Write-Host " Warnings:" -ForegroundColor Yellow
        foreach ($w in $Warnings) { Write-Host "   - $w" -ForegroundColor Yellow }
    }
    Write-Host " Next: run dump_windows.bat with the tablet in BROM mode."
    $exitCode = 0
}
catch {
    Write-Host ""
    Write-Host "SETUP FAILED during step: $script:StepName" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Full log: $(Join-Path $Root 'setup.log')" -ForegroundColor Red
    $exitCode = 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
exit $exitCode
