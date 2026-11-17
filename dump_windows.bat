@echo off
cd /d "%~dp0"
echo ==========================================================
echo  🚀 Starting MediaTek Live Partition Dump
echo  1. Power OFF your tablet completely.
echo  2. Hold BOTH Volume Up + Volume Down (no Power button).
echo  3. Plug in the USB cable while holding both buttons.
echo ==========================================================
tools\mtkclient\.venv\Scripts\python.exe tools\mtkclient\mtk.py r "boot_b,init_boot_b,vbmeta_b" "tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img" --skipwdt
if exist tablet_backup\boot_b.img (
    copy /y tablet_backup\*.img tablet_backup\STOCK_ORIGINALS\ >nul
    echo.
    echo ==========================================================
    echo 🎉 SUCCESS: Partitions dumped and original stock copies
    echo safely archived in tablet_backup\STOCK_ORIGINALS\
    echo ==========================================================
)
pause
