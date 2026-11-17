@echo off
setlocal
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

:: 1. Ensure tools and tablet_backup directories exist
if not exist "%~dp0tools" mkdir "%~dp0tools"
if not exist "%~dp0tablet_backup" mkdir "%~dp0tablet_backup"

:: 2. Download and extract Android SDK Platform-Tools directly into tools\platform-tools\
if not exist "%~dp0tools\platform-tools\adb.exe" (
    echo [..] Downloading Android SDK Platform-Tools (adb.exe and fastboot.exe)...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
        "$zip = '%~dp0tools\platform-tools.zip'; " ^
        "$url = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'; " ^
        "try { Invoke-WebRequest -Uri $url -OutFile $zip } catch { if (Get-Command curl.exe -ErrorAction SilentlyContinue) { & curl.exe -L --ssl-no-revoke -sS --retry 2 -o $zip $url } }; " ^
        "Add-Type -AssemblyName System.IO.Compression.FileSystem; " ^
        "if (Test-Path '%~dp0tools\platform-tools') { Remove-Item '%~dp0tools\platform-tools' -Recurse -Force }; " ^
        "[IO.Compression.ZipFile]::ExtractToDirectory($zip, '%~dp0tools'); " ^
        "Remove-Item $zip -Force"
    if exist "%~dp0tools\platform-tools\adb.exe" (
        echo   [ok] Android SDK Platform-Tools extracted to tools\platform-tools\
    ) else (
        echo   [!] Warning: Direct extraction check failed. setup_windows.ps1 will retry.
    )
) else (
    echo   [ok] Android SDK Platform-Tools already present in tools\platform-tools\
)

:: 3. Pre-download Magisk v31.1 APK directly into tablet_backup\Magisk.apk
if not exist "%~dp0tablet_backup\Magisk.apk" (
    echo [..] Downloading Magisk v31.1 APK into tablet_backup\Magisk.apk...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
        "$apk = '%~dp0tablet_backup\Magisk.apk'; " ^
        "$url = 'https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk'; " ^
        "try { Invoke-WebRequest -Uri $url -OutFile $apk } catch { if (Get-Command curl.exe -ErrorAction SilentlyContinue) { & curl.exe -L --ssl-no-revoke -sS --retry 2 -o $apk $url } }"
    if exist "%~dp0tablet_backup\Magisk.apk" (
        echo   [ok] Magisk v31.1 APK ready in tablet_backup\Magisk.apk
    ) else (
        echo   [!] Warning: Magisk APK download failed. setup_windows.ps1 will retry.
    )
) else (
    echo   [ok] Magisk v31.1 APK already present in tablet_backup\Magisk.apk
)

:: 4. Run complete unattended Windows environment setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==============================================================
    echo  Setup encountered an issue. See setup.log for details.
    echo ==============================================================
)
echo.
pause
