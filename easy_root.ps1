# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - 1-Click Fastboot Unlock & Root (Windows)
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Acer One 8 (T4-82L Gen 2) - 1-Click Fastboot Root" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate fastboot executable
$Fastboot = "tools\platform-tools\fastboot.exe"
if (-not (Test-Path $Fastboot)) {
    $FastbootCmd = Get-Command fastboot -ErrorAction SilentlyContinue
    if ($FastbootCmd) {
        $Fastboot = "fastboot"
    } else {
        Write-Host "❌ Error: fastboot not found at tools\platform-tools\fastboot.exe or in PATH." -ForegroundColor Red
        Write-Host "Please run setup_windows.bat first." -ForegroundColor Yellow
        exit 1
    }
}

# 2. Verify patched image exists
$PatchedImg = "tablet_backup\init_boot_patched.img"
if (-not (Test-Path $PatchedImg)) {
    Write-Host "❌ Error: Patched boot image not found at $PatchedImg" -ForegroundColor Red
    exit 1
}

# 3. Wait for device in Fastboot mode
Write-Host "`n[1/4] Checking for Fastboot connection..." -ForegroundColor Yellow
Write-Host "Make sure your tablet is in FASTBOOT mode (Power off -> hold Power + Vol Up -> Fastboot)."
$fbOut = & $Fastboot devices 2>&1
while (-not ($fbOut -match "fastboot")) {
    Start-Sleep -Seconds 2
    $fbOut = & $Fastboot devices 2>&1
}
Write-Host "  ✓ Tablet detected in Fastboot mode!" -ForegroundColor Green

# 4. Unlock Bootloader
Write-Host "`n[2/4] Unlocking Bootloader..." -ForegroundColor Yellow
Write-Host "  ⚠️  LOOK AT YOUR TABLET SCREEN NOW!" -ForegroundColor Magenta
Write-Host "  👉 Press VOLUME UP on the tablet to confirm bootloader unlock." -ForegroundColor Magenta
& $Fastboot flashing unlock
Write-Host "  ✓ Bootloader unlock command sent." -ForegroundColor Green
Write-Host "  Waiting for tablet to confirm unlock and re-enter Fastboot mode..." -ForegroundColor Gray
Start-Sleep -Seconds 2
$fbOut = & $Fastboot devices 2>&1
while (-not ($fbOut -match "fastboot")) {
    Start-Sleep -Seconds 1
    $fbOut = & $Fastboot devices 2>&1
}
Write-Host "  ✓ Tablet confirmed ready in Fastboot mode!" -ForegroundColor Green

# 5. Flash Patched init_boot to both slots
Write-Host "`n[3/4] Flashing Magisk Root to init_boot partitions..." -ForegroundColor Yellow
& $Fastboot flash init_boot_a $PatchedImg
& $Fastboot flash init_boot_b $PatchedImg
Write-Host "  ✓ init_boot successfully flashed to both slots A & B!" -ForegroundColor Green

# 6. Reboot device
Write-Host "`n[4/4] Rebooting tablet into Android..." -ForegroundColor Yellow
& $Fastboot reboot
Write-Host "  ✓ Tablet is rebooting!" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "🎉 ROOT FLASH COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host " 1. Let the tablet finish booting and complete the initial setup OFFLINE."
Write-Host "    (DO NOT connect to Wi-Fi yet!)"
Write-Host " 2. Enable Developer Options (Settings -> About -> Tap 'Build Number' 7 times)."
Write-Host " 3. Enable USB Debugging in Developer Options."
Write-Host " 4. Run 'block_mdm.bat' to permanently neutralize institutional Zero-Touch/MDM."
Write-Host "==========================================================" -ForegroundColor Cyan
