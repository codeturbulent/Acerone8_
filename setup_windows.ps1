# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - 100% Automated Environment Setup (Windows)
# Fully automated: Zero prompts, zero clicks, no Git or admin rights required.
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"
# Speeds up Invoke-WebRequest by disabling the slow PowerShell progress render
$ProgressPreference = "SilentlyContinue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " 🚀 Acer One 8 - Automated Environment Setup (Windows)" -ForegroundColor Cyan
Write-Host "    (Zero user interaction required - fully automated)" -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Create Workspace Directories
Write-Host "`n[1/6] Creating workspace folders..." -ForegroundColor Yellow
$Dirs = @(
    "tools",
    "tools\drivers",
    "tablet_backup",
    "tablet_backup\STOCK_ORIGINALS"
)
foreach ($d in $Dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}
Write-Host "  ✓ Folders ready: tools\, tablet_backup\STOCK_ORIGINALS\" -ForegroundColor Green

# Helper function to refresh environment PATH
function Refresh-EnvPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
    
    # Also include standard user Python paths if they exist
    $pyUserDir = "$env:LOCALAPPDATA\Programs\Python\Python311"
    if (Test-Path $pyUserDir) {
        $env:Path = "$pyUserDir;$pyUserDir\Scripts;$env:Path"
    }
}

# 2. Check or Silently Install Python 3.11 (No Admin / UAC prompt needed)
Write-Host "`n[2/6] Checking Python installation..." -ForegroundColor Yellow
Refresh-EnvPath
$pyCmd = Get-Command python -ErrorAction SilentlyContinue

if (-not $pyCmd) {
    Write-Host "  Python not detected. Downloading official standalone installer from python.org..." -ForegroundColor Cyan
    $pyArch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
    $pyUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-$pyArch.exe"
    $pyInstaller = "tools\python-installer.exe"
    
    Write-Host "  Downloading Python 3.11 (~25 MB)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $pyUrl -OutFile $pyInstaller
    
    Write-Host "  Installing Python silently into user profile (no UAC / admin needed)..." -ForegroundColor Gray
    $installArgs = "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0 SimpleInstall=1"
    $proc = Start-Process -FilePath $pyInstaller -ArgumentList $installArgs -Wait -PassThru
    
    Remove-Item -Path $pyInstaller -Force -ErrorAction SilentlyContinue
    Refresh-EnvPath
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
}

if (-not $pyCmd) {
    # Direct check fallback in AppData
    $directPy = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"
    if (Test-Path $directPy) {
        $env:Path = "$env:LOCALAPPDATA\Programs\Python\Python311;$env:LOCALAPPDATA\Programs\Python\Python311\Scripts;$env:Path"
        $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    }
}

if ($pyCmd) {
    $pyVer = python --version 2>&1
    Write-Host "  ✓ Python ready: $pyVer" -ForegroundColor Green
} else {
    Write-Host "  ❌ Python installation failed. Please install Python 3.10+ manually." -ForegroundColor Red
    exit 1
}

# 3. Download Android SDK Platform-Tools (ADB & Fastboot)
Write-Host "`n[3/6] Setting up Android SDK Platform-Tools (ADB & Fastboot)..." -ForegroundColor Yellow
$AdbExe = "tools\platform-tools\adb.exe"
if (-not (Test-Path $AdbExe)) {
    Write-Host "  Downloading Platform-Tools..." -ForegroundColor Gray
    $PToolsZip = "tools\platform-tools.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $PToolsZip
    Write-Host "  Extracting Platform-Tools..." -ForegroundColor Gray
    Expand-Archive -Path $PToolsZip -DestinationPath "tools" -Force
    Remove-Item -Path $PToolsZip -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Platform-Tools extracted to tools\platform-tools\" -ForegroundColor Green
} else {
    Write-Host "  ✓ Platform-Tools already present." -ForegroundColor Green
}
$env:Path = "$ScriptDir\tools\platform-tools;$env:Path"

# 4. Download Google Windows USB Driver & Zadig Driver Installer
Write-Host "`n[4/6] Downloading drivers and tools..." -ForegroundColor Yellow

# Google Windows USB Driver
$WinUsbInf = "tools\drivers\usb_driver\android_winusb.inf"
if (-not (Test-Path $WinUsbInf)) {
    Write-Host "  Downloading Google USB Driver ZIP..." -ForegroundColor Gray
    $DriverZip = "tools\usb_driver.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/usb_driver_r13-windows.zip" -OutFile $DriverZip
    Expand-Archive -Path $DriverZip -DestinationPath "tools\drivers" -Force
    Remove-Item -Path $DriverZip -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Google USB Driver extracted to tools\drivers\usb_driver\" -ForegroundColor Green
} else {
    Write-Host "  ✓ Google USB Driver already present." -ForegroundColor Green
}

# Zadig 2.9 (MediaTek Preloader & BootROM Driver Switcher)
$ZadigExe = "tools\zadig-2.9.exe"
if (-not (Test-Path $ZadigExe)) {
    Write-Host "  Downloading Zadig 2.9..." -ForegroundColor Gray
    Invoke-WebRequest -Uri "https://github.com/pbatard/libwdi/releases/download/v1.5.1/zadig-2.9.exe" -OutFile $ZadigExe
    Write-Host "  ✓ Zadig downloaded to tools\zadig-2.9.exe" -ForegroundColor Green
} else {
    Write-Host "  ✓ Zadig already present." -ForegroundColor Green
}

# 5. Setup mtkclient (Direct ZIP download - No Git required!)
Write-Host "`n[5/6] Setting up mtkclient..." -ForegroundColor Yellow
$MtkDir = "tools\mtkclient"
if (-not (Test-Path "$MtkDir\mtk.py")) {
    Write-Host "  Downloading mtkclient archive from GitHub..." -ForegroundColor Gray
    $MtkZip = "tools\mtkclient.zip"
    Invoke-WebRequest -Uri "https://github.com/bkerler/mtkclient/archive/refs/heads/main.zip" -OutFile $MtkZip
    Write-Host "  Extracting mtkclient..." -ForegroundColor Gray
    Expand-Archive -Path $MtkZip -DestinationPath "tools" -Force
    Remove-Item -Path $MtkZip -Force -ErrorAction SilentlyContinue
    if (Test-Path "tools\mtkclient-main") {
        if (Test-Path $MtkDir) { Remove-Item -Path $MtkDir -Recurse -Force }
        Move-Item -Path "tools\mtkclient-main" -Destination $MtkDir -Force
    }
    Write-Host "  ✓ mtkclient downloaded and extracted." -ForegroundColor Green
} else {
    Write-Host "  ✓ mtkclient already present." -ForegroundColor Green
}

# Apply patched mtk_preloader.py
if (Test-Path "mtk_preloader.py") {
    Write-Host "  Applying patched mtk_preloader.py to tools\mtkclient..." -ForegroundColor Gray
    Copy-Item -Path "mtk_preloader.py" -Destination "tools\mtkclient\mtkclient\Library\mtk_preloader.py" -Force
    Write-Host "  ✓ Modified mtk_preloader.py applied." -ForegroundColor Green
}

# 6. Configure Python Virtual Environment & Install Dependencies
Write-Host "`n[6/6] Configuring Python virtual environment..." -ForegroundColor Yellow
$VenvPython = "$MtkDir\.venv\Scripts\python.exe"
$VenvPip    = "$MtkDir\.venv\Scripts\pip.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Host "  Creating isolated virtual environment..." -ForegroundColor Gray
    python -m venv "$MtkDir\.venv"
}

Write-Host "  Installing required libraries (pycryptodomex, pyusb, pyserial, colorama)..." -ForegroundColor Gray
& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPip install --quiet pycryptodomex pyusb pyserial colorama

# Verify Cryptodome import
$VerifyCode = "from Cryptodome.Cipher import AES; import usb.core; print('OK')"
$VerifyResult = & $VenvPython -c $VerifyCode 2>&1
if ($VerifyResult -match "OK") {
    Write-Host "  ✓ Python virtual environment verified!" -ForegroundColor Green
} else {
    Write-Host "  ❌ Failed to verify Python packages: $VerifyResult" -ForegroundColor Red
    exit 1
}

# Generate 1-click dump_windows.bat
$DumpBatContent = @"
@echo off
cd /d "%~dp0"
echo ==========================================================
echo  Starting MediaTek Live Partition Dump
echo  1. Power OFF your tablet completely.
echo  2. Hold BOTH Volume Up + Volume Down (no Power button).
echo  3. Plug in the USB cable while holding both buttons.
echo ==========================================================
tools\mtkclient\.venv\Scripts\python.exe tools\mtkclient\mtk.py r "boot_b,init_boot_b,vbmeta_b" "tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img" --skipwdt
if exist tablet_backup\boot_b.img (
    copy /y tablet_backup\*.img tablet_backup\STOCK_ORIGINALS\ >nul
    echo.
    echo ==========================================================
    echo Stock partitions saved safely to tablet_backup\STOCK_ORIGINALS\
    echo ==========================================================
)
pause
"@
Set-Content -Path "dump_windows.bat" -Value $DumpBatContent -Force

# Generate 1-click dump_windows.ps1
$DumpPs1Content = @"
`$ScriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$ScriptDir
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting MediaTek Live Partition Dump" -ForegroundColor Cyan
Write-Host " 1. Power OFF your tablet completely."
Write-Host " 2. Hold BOTH Volume Up + Volume Down (no Power button)."
Write-Host " 3. Plug in the USB cable while holding both buttons."
Write-Host "==========================================================" -ForegroundColor Cyan
& "tools\mtkclient\.venv\Scripts\python.exe" tools\mtkclient\mtk.py r `"boot_b,init_boot_b,vbmeta_b`" `"tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img`" --skipwdt
if (Test-Path "tablet_backup\boot_b.img") {
    Copy-Item -Path "tablet_backup\*.img" -Destination "tablet_backup\STOCK_ORIGINALS\" -Force
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "Stock partitions saved safely to tablet_backup\STOCK_ORIGINALS\" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
"@
Set-Content -Path "dump_windows.ps1" -Value $DumpPs1Content -Force

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "🎉 Windows Setup Complete! (Zero user interaction required)" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "`nDRIVER CONFIGURATION INSTRUCTIONS (REQUIRED ONCE):" -ForegroundColor Yellow
Write-Host "1. Launch Zadig by double-clicking: tools\zadig-2.9.exe"
Write-Host "2. In Zadig, click 'Options' -> check 'List All Devices'."
Write-Host "3. Power OFF your tablet. Hold Volume Up + Volume Down and plug in USB."
Write-Host "4. Look for 'MediaTek PreLoader USB VCOM Port' or 'MTK USB Port' (VID: 0E8D)."
Write-Host "5. Under the target driver, select 'libusb-win32' (or 'WinUSB') and click 'Replace Driver'."
Write-Host "`nWhen ready, simply double-click 'dump_windows.bat' to dump your live partitions!" -ForegroundColor Cyan
