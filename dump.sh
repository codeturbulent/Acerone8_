#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "=========================================================="
echo " 🚀 Starting MediaTek Live Partition Dump"
echo " 1. Power OFF your tablet completely."
echo " 2. Hold BOTH Volume Up + Volume Down (no Power button)."
echo " 3. Plug in the USB cable while holding both buttons."
echo "=========================================================="

sudo tools/mtkclient/.venv/bin/python3 tools/mtkclient/mtk.py r boot_b,init_boot_b,vbmeta_b \
    tablet_backup/boot_b.img,tablet_backup/init_boot_b.img,tablet_backup/vbmeta_b.img \
    --skipwdt

if [ -f tablet_backup/boot_b.img ]; then
    cp -f tablet_backup/*.img tablet_backup/STOCK_ORIGINALS/
    echo ""
    echo "=========================================================="
    echo "🎉 SUCCESS: Partitions dumped and original stock copies"
    echo "safely archived in tablet_backup/STOCK_ORIGINALS/!"
    echo "=========================================================="
fi
