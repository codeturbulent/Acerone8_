$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Starting MediaTek Live Partition Dump (Slots A & B)" -ForegroundColor Cyan
Write-Host " 1. Power OFF your tablet completely."
Write-Host " 2. Hold BOTH Volume Up + Volume Down (no Power button)."
Write-Host " 3. Plug in the USB cable while holding both buttons."
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path "tablet_backup\STOCK_ORIGINALS")) {
    New-Item -ItemType Directory -Path "tablet_backup\STOCK_ORIGINALS" -Force | Out-Null
}

& "$ScriptDir\tools\mtkclient\.venv\Scripts\python.exe" "$ScriptDir\tools\mtkclient\mtk.py" r "boot_a,boot_b,init_boot_a,init_boot_b,vbmeta_a,vbmeta_b" "tablet_backup\boot_a.img,tablet_backup\boot_b.img,tablet_backup\init_boot_a.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_a.img,tablet_backup\vbmeta_b.img" --skipwdt

if (Test-Path "tablet_backup\boot_b.img") {
    Get-ChildItem "tablet_backup\*.img" | ForEach-Object {
        $dest = Join-Path "tablet_backup\STOCK_ORIGINALS" $_.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $_.FullName $dest -Force
        }
    }
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "🎉 SUCCESS: Partitions dumped and original stock copies" -ForegroundColor Green
    Write-Host "safely archived in tablet_backup\STOCK_ORIGINALS\" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
}
