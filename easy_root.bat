@echo off
setlocal enabledelayedexpansion
title Acer One 8 - 1-Click Unlock & Root
color 0b
cd /d "%~dp0"

echo ==========================================================
echo   Acer One 8 (T4-82L Gen 2) - 1-Click Fastboot Root
echo ==========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0easy_root.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [!] Process encountered an error. Check the messages above.
)
echo.
pause
