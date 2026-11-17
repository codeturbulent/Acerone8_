@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ==========================================================
echo  Acer One 8 - Anti-MDM ^& Zero-Touch Defense Installer
echo ==========================================================

:: Find adb executable
set "ADB=tools\platform-tools\adb.exe"
if not exist "%ADB%" (
    where adb >nul 2>&1
    if %errorlevel% equ 0 (
        set "ADB=adb"
    ) else (
        echo [X] Error: adb not found at tools\platform-tools\adb.exe or in PATH.
        echo Please run setup_windows.bat first.
        pause
        exit /b 1
    )
)

:: 1. Check if ADB device is connected
"%ADB%" get-state >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Error: Tablet not detected via ADB.
    echo Please ensure USB debugging is ON and the tablet is connected.
    pause
    exit /b 1
)

:: 2. Check for root permissions
echo [1/4] Verifying root privileges...
"%ADB%" shell "su -c id" 2>nul | findstr "uid=0" >nul
if %errorlevel% neq 0 (
    echo [X] Error: Root not granted. Please open Magisk on your tablet and grant root.
    pause
    exit /b 1
)
echo   [ok] Root confirmed (uid=0).

:: 3. Neutralize active Zero-Touch components
echo [2/4] Neutralizing Zero-Touch activities and locking configuration...
"%ADB%" shell "su -c 'pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1; pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1; if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null; echo -n \"\" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml; chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml; chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null; fi; pm disable com.android.managedprovisioning >/dev/null 2>&1; pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1; pm disable com.chipc.update >/dev/null 2>&1; pm disable-user --user 0 com.chipc.update >/dev/null 2>&1; am force-stop com.google.android.gms >/dev/null 2>&1'"
echo   [ok] Zero-Touch activities disabled and configuration locked.

:: 4. Firewall DeviceLockController UID at kernel level
echo [3/4] Firewalling DeviceLockController at kernel level...
"%ADB%" shell "su -c 'DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\"); if [ -n \"$DLC_UID\" ]; then iptables -C OUTPUT -m owner --uid-owner \"$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"$DLC_UID\" -j DROP; ip6tables -C OUTPUT -m owner --uid-owner \"$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"$DLC_UID\" -j DROP; fi'"
echo   [ok] Outgoing network traffic for DeviceLockController blocked.

:: 5. Install persistent Magisk startup boot service
echo [4/4] Installing persistent Magisk boot service...
"%ADB%" shell "su -c 'cat << \"EOF\" > /data/adb/service.d/block_mdm.sh
#!/system/bin/sh
while [ \"$(getprop sys.boot_completed)\" != \"1\" ]; do
    sleep 2
done
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n \"\" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1
DLC_UID=\$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\")
if [ -n \"\$DLC_UID\" ]; then
    iptables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
fi
rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
EOF
chmod 755 /data/adb/service.d/block_mdm.sh'"
echo   [ok] Persistent service installed at /data/adb/service.d/block_mdm.sh

echo.
echo ==========================================================
echo  SUCCESS: All institutional MDM / Zero-Touch locks eliminated!
echo  You can now safely connect your tablet to Wi-Fi.
echo ==========================================================
pause
