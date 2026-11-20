#!/usr/bin/env bash
# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - 1-Click Fastboot Unlock & Root (Linux)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================================="
echo " 🚀 Acer One 8 (T4-82L Gen 2) - 1-Click Fastboot Root"
echo "=========================================================="

FASTBOOT="tools/platform-tools/fastboot"
if [ ! -f "$FASTBOOT" ]; then
    if command -v fastboot >/dev/null 2>&1; then
        FASTBOOT="fastboot"
    else
        echo "❌ Error: fastboot not found. Run ./setup_linux.sh first."
        exit 1
    fi
fi

PATCHED_IMG="tablet_backup/init_boot_patched.img"
if [ ! -f "$PATCHED_IMG" ]; then
    echo "❌ Error: $PATCHED_IMG not found."
    exit 1
fi

echo -e "\n[1/4] Checking for Fastboot connection..."
echo "Put tablet in FASTBOOT mode (Power off -> hold Power + Vol Up -> Fastboot)."
while ! $FASTBOOT devices | grep -q "fastboot"; do
    sleep 2
done
echo "  ✓ Tablet detected in Fastboot mode!"

echo -e "\n[2/4] Unlocking Bootloader..."
echo "  ⚠️  LOOK AT TABLET SCREEN: Press VOLUME UP to confirm unlock!"
$FASTBOOT flashing unlock || true
echo "  Waiting for tablet to confirm unlock and re-enter Fastboot mode..."
sleep 2
while ! $FASTBOOT devices | grep -q "fastboot"; do
    sleep 1
done
echo "  ✓ Tablet confirmed ready in Fastboot mode!"

echo -e "\n[3/4] Flashing Magisk Root to init_boot partitions..."
$FASTBOOT flash init_boot_a "$PATCHED_IMG"
$FASTBOOT flash init_boot_b "$PATCHED_IMG"
echo "  ✓ init_boot successfully flashed to both slots A & B!"

echo -e "\n[4/4] Rebooting tablet into Android..."
$FASTBOOT reboot
echo "  ✓ Tablet is rebooting!"

echo -e "\n=========================================================="
echo "🎉 ROOT FLASH COMPLETED SUCCESSFULLY!"
echo "=========================================================="
echo "Next Steps:"
echo " 1. Complete offline initial setup (DO NOT connect Wi-Fi yet!)."
echo " 2. Enable Developer Options -> USB Debugging."
echo " 3. Run ./block_mdm.sh to neutralize institutional Zero-Touch/MDM."
echo "=========================================================="
