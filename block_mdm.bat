@echo off
setlocal
title Acer One 8 - Anti-MDM ^& Zero-Touch Defense Installer
cd /d "%~dp0"

echo ==========================================================
echo  Acer One 8 - Anti-MDM ^& Zero-Touch Defense Installer
echo ==========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0block_mdm.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [!] Process encountered an error. See output above.
)
echo.
pause
