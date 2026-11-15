#!/usr/bin/env bash
set -e

PATCHED_IMG="../tablet_backup/magisk_patched.img"

if [ ! -f "$PATCHED_IMG" ]; then
    echo "Error: $PATCHED_IMG not found. Please patch init_boot.img in Magisk first."
    exit 1
fi

echo "Rebooting tablet to bootloader..."
adb reboot bootloader

echo "Flashing patched init_boot to slot B..."
fastboot flash init_boot_b "$PATCHED_IMG"

echo "Rebooting into rooted Android..."
fastboot reboot

echo "Done! Open Magisk app on the tablet to verify root."
