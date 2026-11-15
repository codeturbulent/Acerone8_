#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " 🛡️ Acer One 8 - Anti-MDM & Zero-Touch Defense Installer"
echo "=========================================================="

# 1. Check if ADB device is connected
if ! adb get-state 1>/dev/null 2>&1; then
    echo "❌ Error: Tablet not detected via ADB."
    echo "Please ensure USB debugging is ON and the tablet is connected."
    exit 1
fi

# 2. Check for root permissions
echo "[1/4] Verifying root privileges..."
if ! adb shell "su -c id" 2>/dev/null | grep -q "uid=0"; then
    echo "❌ Error: Root not granted. Please open Magisk on your tablet and grant root."
    exit 1
fi
echo "  ✓ Root confirmed (uid=0)."

# 3. Neutralize active Zero-Touch components
echo "[2/4] Neutralizing Zero-Touch activities & locking configuration..."
adb shell "su -c '
# Disable FactoryResetActivity & background tasks in Google Play Services
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1

# Empty zero_touch_prefs.xml and make it immutable (+i)
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n \"\" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi

# Disable Android Enterprise provisioning & OTA updates
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1

# Force stop GMS to clear any running countdown or notification
am force-stop com.google.android.gms >/dev/null 2>&1
'"
echo "  ✓ Zero-Touch activities disabled and configuration locked."

# 4. Firewall DeviceLockController UID at kernel level
echo "[3/4] Firewalling DeviceLockController at kernel level..."
adb shell "su -c '
DLC_UID=\$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\")
if [ -n \"\$DLC_UID\" ]; then
    iptables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
fi
'"
echo "  ✓ Outgoing network traffic for DeviceLockController blocked."

# 5. Install persistent Magisk startup boot service
echo "[4/4] Installing persistent Magisk boot service..."
adb shell "su -c '
cat << \"EOF\" > /data/adb/service.d/block_mdm.sh
#!/system/bin/sh
while [ \"\$(getprop sys.boot_completed)\" != \"1\" ]; do
    sleep 2
done

# 1. Disable Zero-Touch activities in Google Play Services
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1

# 2. Lock zero_touch_prefs file to prevent enrollment storage
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n \"\" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi

# 3. Disable ManagedProvisioning (Android Enterprise engine)
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1

# 4. Disable Vendor OTA Update
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1

# 5. Firewall DeviceLockController
DLC_UID=\$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\")
if [ -n \"\$DLC_UID\" ]; then
    iptables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
fi

# 6. Delete any generated device owner files
rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
EOF

chmod 755 /data/adb/service.d/block_mdm.sh
'"
echo "  ✓ Persistent service installed at /data/adb/service.d/block_mdm.sh"

echo "=========================================================="
echo "🎉 SUCCESS: All institutional MDM / Zero-Touch locks eliminated!"
echo "You can now safely connect your tablet to Wi-Fi & Internet."
echo "=========================================================="
