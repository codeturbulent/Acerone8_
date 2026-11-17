# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - Automated Environment Setup (Windows)
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " 🚀 Acer One 8 - Environment & Dependency Setup (Windows)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Create Workspace Directories
Write-Host "`n[1/7] Creating workspace folder structure..." -ForegroundColor Yellow
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
Write-Host "  ✓ Folders created: tools\, tools\drivers\, tablet_backup\STOCK_ORIGINALS\" -ForegroundColor Green

# Function to refresh environment path
function Refresh-EnvPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
}

# 2. Check and Install Git & Python (via winget or Scoop)
Write-Host "`n[2/7] Checking for Python and Git..." -ForegroundColor Yellow

$hasPython = [bool](Get-Command python -ErrorAction SilentlyContinue)
$hasGit    = [bool](Get-Command git -ErrorAction SilentlyContinue)

if (-not $hasPython -or -not $hasGit) {
    Write-Host "  ⚠️ Missing prerequisites detected (Python: $hasPython, Git: $hasGit)." -ForegroundColor DarkYellow
    
    # Try winget first if available
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $installedViaWinget = $false

    if ($hasWinget) {
        Write-Host "  Attempting automated installation via winget..." -ForegroundColor Cyan
        try {
            if (-not $hasPython) {
                Write-Host "  Installing Python 3.11 via winget..." -ForegroundColor Gray
                winget install -e --id Python.Python.3.11 --accept-source-agreements --accept-package-agreements --silent
            }
            if (-not $hasGit) {
                Write-Host "  Installing Git via winget..." -ForegroundColor Gray
                winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements --silent
            }
            Refresh-EnvPath
            $hasPython = [bool](Get-Command python -ErrorAction SilentlyContinue)
            $hasGit    = [bool](Get-Command git -ErrorAction SilentlyContinue)
            if ($hasPython -and $hasGit) {
                $installedViaWinget = $true
                Write-Host "  ✓ Python and Git installed successfully via winget!" -ForegroundColor Green
            }
        } catch {
            Write-Host "  winget install encountered an issue, falling back to Scoop..." -ForegroundColor DarkYellow
        }
    }

    # If winget was not available or failed, install via Scoop
    if (-not $installedViaWinget -and (-not $hasPython -or -not $hasGit)) {
        Write-Host "  Setting up Scoop package manager for Windows..." -ForegroundColor Cyan
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        $hasScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
        if (-not $hasScoop) {
            Invoke-RestMethod -Uri https://get.scoop.it | Invoke-Expression
            Refresh-EnvPath
        }

        if (-not $hasPython) {
            Write-Host "  Installing Python via Scoop..." -ForegroundColor Gray
            scoop install python
        }
        if (-not $hasGit) {
            Write-Host "  Installing Git via Scoop..." -ForegroundColor Gray
            scoop install git
        }
        Refresh-EnvPath
    }
}

# Verify again
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pyCmd) {
    $pyVer = python --version 2>&1
    Write-Host "  ✓ Python ready: $pyVer" -ForegroundColor Green
} else {
    Write-Host "  ❌ Python could not be installed automatically. Please install Python 3.10+ from python.org and check 'Add Python to PATH'." -ForegroundColor Red
    exit 1
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    Write-Host "  ✓ Git ready." -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Git not detected in PATH; setup will use direct archive downloads." -ForegroundColor DarkYellow
}

# 3. Download Android SDK Platform-Tools (ADB & Fastboot)
Write-Host "`n[3/7] Setting up Android SDK Platform-Tools (ADB & Fastboot)..." -ForegroundColor Yellow
$AdbExe = "tools\platform-tools\adb.exe"
if (-not (Test-Path $AdbExe)) {
    Write-Host "  Downloading Platform-Tools for Windows..." -ForegroundColor Gray
    $PToolsZip = "tools\platform-tools.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $PToolsZip
    Write-Host "  Extracting Platform-Tools..." -ForegroundColor Gray
    Expand-Archive -Path $PToolsZip -DestinationPath "tools" -Force
    Remove-Item -Path $PToolsZip -Force
    Write-Host "  ✓ Platform-Tools extracted to tools\platform-tools\" -ForegroundColor Green
} else {
    Write-Host "  ✓ Platform-Tools already present." -ForegroundColor Green
}
$env:Path = "$ScriptDir\tools\platform-tools;$env:Path"

# 4. Download Google Windows USB Driver (for Fastboot & ADB)
Write-Host "`n[4/7] Setting up Google Windows USB Driver..." -ForegroundColor Yellow
$WinUsbInf = "tools\drivers\usb_driver\android_winusb.inf"
if (-not (Test-Path $WinUsbInf)) {
    Write-Host "  Downloading Google USB Driver ZIP..." -ForegroundColor Gray
    $DriverZip = "tools\usb_driver.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/usb_driver_r13-windows.zip" -OutFile $DriverZip
    Write-Host "  Extracting Google USB Driver..." -ForegroundColor Gray
    Expand-Archive -Path $DriverZip -DestinationPath "tools\drivers" -Force
    Remove-Item -Path $DriverZip -Force
    Write-Host "  ✓ Google USB Driver extracted to tools\drivers\usb_driver\" -ForegroundColor Green
} else {
    Write-Host "  ✓ Google USB Driver already present." -ForegroundColor Green
}

# 5. Download Zadig (MediaTek Preloader & BootROM Driver Switcher)
Write-Host "`n[5/7] Downloading Zadig USB Driver Tool..." -ForegroundColor Yellow
$ZadigExe = "tools\zadig-2.9.exe"
if (-not (Test-Path $ZadigExe)) {
    Write-Host "  Downloading Zadig 2.9..." -ForegroundColor Gray
    Invoke-WebRequest -Uri "https://github.com/pbatard/libwdi/releases/download/v1.5.1/zadig-2.9.exe" -OutFile $ZadigExe
    Write-Host "  ✓ Zadig downloaded to tools\zadig-2.9.exe" -ForegroundColor Green
} else {
    Write-Host "  ✓ Zadig already present." -ForegroundColor Green
}

# 6. Setup mtkclient & Apply Helio G85 Preloader Patch
Write-Host "`n[6/7] Setting up mtkclient..." -ForegroundColor Yellow
$MtkDir = "tools\mtkclient"
if (-not (Test-Path "$MtkDir\mtk.py")) {
    if ($gitCmd) {
        Write-Host "  Cloning mtkclient via Git..." -ForegroundColor Gray
        git clone --depth 1 https://github.com/bkerler/mtkclient $MtkDir
    } else {
        Write-Host "  Downloading mtkclient archive from GitHub..." -ForegroundColor Gray
        $MtkZip = "tools\mtkclient.zip"
        Invoke-WebRequest -Uri "https://github.com/bkerler/mtkclient/archive/refs/heads/main.zip" -OutFile $MtkZip
        Expand-Archive -Path $MtkZip -DestinationPath "tools" -Force
        Remove-Item -Path $MtkZip -Force
        if (Test-Path "tools\mtkclient-main") {
            Rename-Item -Path "tools\mtkclient-main" -NewName "mtkclient"
        }
    }
    Write-Host "  ✓ mtkclient downloaded." -ForegroundColor Green
} else {
    Write-Host "  ✓ mtkclient already present." -ForegroundColor Green
}

# Apply patched mtk_preloader.py
if (Test-Path "mtk_preloader.py") {
    Write-Host "  Applying patched mtk_preloader.py to tools\mtkclient..." -ForegroundColor Gray
    Copy-Item -Path "mtk_preloader.py" -Destination "tools\mtkclient\mtkclient\Library\mtk_preloader.py" -Force
    Write-Host "  ✓ Modified mtk_preloader.py applied." -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Warning: mtk_preloader.py not found in root. Skipping patch." -ForegroundColor DarkYellow
}

# 7. Configure Python Virtual Environment & Install Dependencies
Write-Host "`n[7/7] Setting up Python virtual environment..." -ForegroundColor Yellow
$VenvPython = "$MtkDir\.venv\Scripts\python.exe"
$VenvPip    = "$MtkDir\.venv\Scripts\pip.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Host "  Creating virtual environment in $MtkDir\.venv..." -ForegroundColor Gray
    python -m venv "$MtkDir\.venv"
}

Write-Host "  Installing required Python modules (pycryptodomex, pyusb, pyserial, colorama)..." -ForegroundColor Gray
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

# Generate dump_windows.bat for easy 1-click execution on Windows
$DumpBatContent = @"
@echo off
cd /d "%~dp0"
echo ==========================================================
echo  Starting MediaTek Live Partition Dump
echo  1. Power OFF your tablet completely.
echo  2. Hold BOTH Volume Up + Volume Down (no Power button).
echo  3. Plug in the USB cable while holding both buttons.
echo ==========================================================
tools\mtkclient\.venv\Scripts\python.exe tools\mtkclient\mtk.py r \"boot_b,init_boot_b,vbmeta_b\" \"tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img\" --skipwdt
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

# Generate dump_windows.ps1
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
Write-Host "🎉 Windows Setup Complete!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "`nDRIVER CONFIGURATION INSTRUCTIONS (REQUIRED ONCE):" -ForegroundColor Yellow
Write-Host "1. Launch Zadig by double-clicking: tools\zadig-2.9.exe"
Write-Host "2. In Zadig, click 'Options' -> check 'List All Devices'."
Write-Host "3. Power OFF your tablet. Hold Volume Up + Volume Down and plug in USB."
Write-Host "4. Look for 'MediaTek PreLoader USB VCOM Port' or 'MTK USB Port' (VID: 0E8D)."
Write-Host "5. Under the target driver, select 'libusb-win32' (or 'WinUSB') and click 'Replace Driver'."
Write-Host "`nWhen ready, simply run 'dump_windows.bat' (or '.\dump_windows.ps1') to dump your live partitions!" -ForegroundColor Cyan
