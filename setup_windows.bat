@echo off
setlocal
cd /d "%~dp0"
title Acer One 8 - Automated Environment Setup Tool

:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ==================================================================
    echo  Requesting Administrator privileges...
    echo ==================================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k cd /d \"\"%~dp0\"\" && powershell -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0setup_windows.ps1\"\"' -Verb RunAs"
    exit /b
)

echo ==================================================================
echo  Starting Acer One 8 Automated Setup for Windows...
echo ==================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1"
if %errorlevel% neq 0 (
    echo.
    echo ==============================================================
    echo  Setup encountered an issue. See setup.log for details.
    echo ==============================================================
)
echo.
pause
