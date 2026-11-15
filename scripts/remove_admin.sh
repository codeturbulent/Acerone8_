#!/usr/bin/env bash
set -e

echo "Checking Device Admin status..."
adb shell "dpm list-owners"

echo "Disabling Device Lock Controller..."
adb shell "su -c 'pm disable-user --user 0 com.android.devicelockcontroller'"

echo "Checking for persistent policy XMLs..."
adb shell "su -c 'rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml'"

echo "Done! Institutional locks have been eliminated."
