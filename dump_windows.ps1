$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Starting MediaTek Live Partition Dump" -ForegroundColor Cyan
Write-Host " 1. Power OFF your tablet completely."
Write-Host " 2. Hold BOTH Volume Up + Volume Down (no Power button)."
Write-Host " 3. Plug in the USB cable while holding both buttons."
Write-Host "==========================================================" -ForegroundColor Cyan

& "tools\mtkclient\.venv\Scripts\python.exe" tools\mtkclient\mtk.py r "boot_b,init_boot_b,vbmeta_b" "tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img" --skipwdt

if (Test-Path "tablet_backup\boot_b.img") {
    Copy-Item -Path "tablet_backup\*.img" -Destination "tablet_backup\STOCK_ORIGINALS\" -Force
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "🎉 SUCCESS: Partitions dumped and original stock copies" -ForegroundColor Green
    Write-Host "safely archived in tablet_backup\STOCK_ORIGINALS\" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
