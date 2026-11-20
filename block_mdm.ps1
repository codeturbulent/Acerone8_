# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - Anti-MDM & Zero-Touch Defense Installer (Windows)
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🛡️ Acer One 8 - Anti-MDM & Zero-Touch Defense Installer" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate adb executable
$Adb = "tools\platform-tools\adb.exe"
if (-not (Test-Path $Adb)) {
    $AdbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($AdbCmd) {
        $Adb = "adb"
    } else {
        Write-Host "❌ Error: adb not found at tools\platform-tools\adb.exe or in PATH." -ForegroundColor Red
        Write-Host "Please run setup_windows.bat first." -ForegroundColor Yellow
        exit 1
    }
}

# 2. Check if ADB device is connected
$state = & $Adb get-state 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Tablet not detected via ADB." -ForegroundColor Red
    Write-Host "Please ensure USB debugging is ON and the tablet is connected." -ForegroundColor Yellow
    exit 1
}

# 3. Auto-install Magisk app if present in tablet_backup
$MagiskApk = "tablet_backup\Magisk.apk"
if (Test-Path $MagiskApk) {
    Write-Host "`n[0/4] Checking Magisk App installation..." -ForegroundColor Yellow
    & $Adb install -r $MagiskApk 2>&1 | Out-Null
    Write-Host "  ✓ Magisk APK installed." -ForegroundColor Green
}

# 4. Check for root permissions
Write-Host "`n[1/4] Verifying root privileges..." -ForegroundColor Yellow
$idOut = & $Adb shell "su -c id" 2>&1
if ($idOut -notmatch "uid=0") {
    Write-Host "❌ Error: Root not granted. Please open Magisk on your tablet and grant root access when prompted." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Root confirmed (uid=0)." -ForegroundColor Green

# Helper function to run root commands cleanly via ADB without escaping errors
function Invoke-RootCommand {
    param([string]$ScriptContent)
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $ScriptContent.Replace("`r`n", "`n"))

    $prevPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Adb push $tempFile /data/local/tmp/_mdm_cmd.sh *> $null
    $pushExit = $LASTEXITCODE
    Remove-Item $tempFile -Force
    if ($pushExit -ne 0) {
        $ErrorActionPreference = $prevPreference
        throw "Failed to push temporary script to /data/local/tmp/_mdm_cmd.sh"
    }

    & $Adb shell "su -c 'sh /data/local/tmp/_mdm_cmd.sh; rm -f /data/local/tmp/_mdm_cmd.sh'"
    $ErrorActionPreference = $prevPreference
}

# 5. Neutralize Zero-Touch components
Write-Host "`n[2/4] Neutralizing Zero-Touch activities & locking configuration..." -ForegroundColor Yellow
$cmdDisable = @'
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n "" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1
am force-stop com.google.android.gms >/dev/null 2>&1
'@
Invoke-RootCommand -ScriptContent $cmdDisable
Write-Host "  ✓ Zero-Touch activities disabled and configuration locked." -ForegroundColor Green

# 6. Firewall DeviceLockController at kernel level
Write-Host "`n[3/4] Firewalling DeviceLockController at kernel level..." -ForegroundColor Yellow
$cmdFirewall = @'
DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n "s/.*uid://p")
if [ -n "$DLC_UID" ]; then
    iptables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
fi
'@
Invoke-RootCommand -ScriptContent $cmdFirewall
Write-Host "  ✓ Outgoing network traffic for DeviceLockController blocked." -ForegroundColor Green

# 7. Install persistent Magisk startup boot service
Write-Host "`n[4/4] Installing persistent Magisk boot service..." -ForegroundColor Yellow
$cmdService = @'
mkdir -p /data/adb/service.d
cat << "EOF" > /data/adb/service.d/block_mdm.sh
#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n "" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1
DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n "s/.*uid://p")
if [ -n "$DLC_UID" ]; then
    iptables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
fi
rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
EOF
chmod 755 /data/adb/service.d/block_mdm.sh
'@
Invoke-RootCommand -ScriptContent $cmdService
Write-Host "  ✓ Persistent boot service installed in /data/adb/service.d/block_mdm.sh" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "🎉 SUCCESS: All institutional MDM / Zero-Touch locks eliminated!" -ForegroundColor Green
Write-Host "You can now safely connect your tablet to Wi-Fi & Internet." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
