#!/system/bin/sh
# Persistent Anti-MDM & Anti-ZeroTouch Defense Script
# Runs on every boot via Magisk (/data/adb/service.d/block_mdm.sh)

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# 1. Disable Zero-Touch Factory Reset & Network Task in Google Play Services
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1

# 2. Lock zero_touch_prefs file to prevent enrollment storage
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n "" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
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
DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n "s/.*uid://p")
if [ -n "$DLC_UID" ]; then
    iptables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
fi

# 6. Delete any generated device owner files
rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
