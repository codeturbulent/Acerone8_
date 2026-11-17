@echo off
title Acer One 8 - Environment Setup Tool
cd /d "%~dp0"
echo ==================================================================
echo  Starting Acer One 8 Automated Setup for Windows...
echo ==================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==============================================================
    echo  Setup encountered an issue. See above output for details.
    echo ==============================================================
)
echo.
pause
