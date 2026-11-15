#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " Installing Persistent Anti-MDM & Anti-Enrollment Defense"
echo "=========================================================="

adb shell "su -c 'cat << \"EOF\" > /data/adb/service.d/block_mdm.sh
#!/system/bin/sh
while [ \"\$(getprop sys.boot_completed)\" != \"1\" ]; do
    sleep 2
done

# Disable Android Zero-Touch Managed Provisioning
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1

# Disable OTA vendor updater
pm disable com.chipc.update >/dev/null 2>&1
pm disable-user --user 0 com.chipc.update >/dev/null 2>&1

# Block DeviceLockController network access
DLC_UID=\$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\")
if [ -n \"\$DLC_UID\" ]; then
    iptables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
fi

# Remove any device owner records
rm -f /data/system/device_owner_2.xml
rm -f /data/system/device_policies.xml
EOF
chmod 755 /data/adb/service.d/block_mdm.sh
'"

echo "Success! Anti-MDM boot service is installed in /data/adb/service.d/block_mdm.sh"
echo "The tablet can now connect to Wi-Fi / Internet with zero risk of re-enrollment."
