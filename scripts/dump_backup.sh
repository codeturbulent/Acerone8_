#!/usr/bin/env bash
set -e

BACKUP_DIR="../tablet_backup"
mkdir -p "$BACKUP_DIR"

echo "=========================================================="
echo " Acer One 8 (T4-82L Gen 2) - Partition Dump"
echo " 1. Power OFF your tablet completely."
echo " 2. Connect USB cable (without buttons or hold Vol Up)."
echo "=========================================================="

python3 ../mtkclient/mtk.py r boot_b,init_boot_b,vbmeta_b \
    "$BACKUP_DIR/boot_b.img,$BACKUP_DIR/init_boot_b.img,$BACKUP_DIR/vbmeta_b.img" \
    --skipwdt

echo "Dumping completed successfully into $BACKUP_DIR!"
