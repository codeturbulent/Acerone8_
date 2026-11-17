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

"%~dp0tools\mtkclient\.venv\Scripts\python.exe" "%~dp0tools\mtkclient\mtk.py" r "boot_a,boot_b,init_boot_a,init_boot_b,vbmeta_a,vbmeta_b" "tablet_backup\boot_a.img,tablet_backup\boot_b.img,tablet_backup\init_boot_a.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_a.img,tablet_backup\vbmeta_b.img" --skipwdt
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
echo ==========================================================
echo  Done. Stock copies are in tablet_backup\STOCK_ORIGINALS\
echo ==========================================================
pause
