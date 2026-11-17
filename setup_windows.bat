@echo off
title Acer One 8 - Environment Setup Tool
cd /d "%~dp0"

:: Check for Administrator privileges and elevate if needed
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [..] Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo ==================================================================
echo  Starting Acer One 8 Automated Setup for Windows (Administrator)...
echo ==================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==============================================================
    echo  Setup encountered an issue. See setup.log for details.
    echo ==============================================================
)
echo.
pause
