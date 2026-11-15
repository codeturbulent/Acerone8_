#!/usr/bin/env bash
set -e

# Resolve absolute path to the repository root regardless of where script is called
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="$REPO_ROOT/tablet_backup"
MTK_DIR="$REPO_ROOT/mtkclient"

mkdir -p "$BACKUP_DIR/STOCK_ORIGINALS"

if [ ! -d "$MTK_DIR" ]; then
    echo "Cloning mtkclient into $MTK_DIR..."
    git clone https://github.com/bkerler/mtkclient "$MTK_DIR"
fi

echo "=========================================================="
echo " Acer One 8 (T4-82L Gen 2) - Partition Dump"
echo " 1. Power OFF your tablet completely."
echo " 2. Connect USB cable (without buttons or hold Vol Up)."
echo "=========================================================="

sudo python3 "$MTK_DIR/mtk.py" r boot_b,init_boot_b,vbmeta_b \
    "$BACKUP_DIR/boot_b.img,$BACKUP_DIR/init_boot_b.img,$BACKUP_DIR/vbmeta_b.img" \
    --skipwdt

echo "Copying untouched stock originals..."
cp "$BACKUP_DIR"/*.img "$BACKUP_DIR/STOCK_ORIGINALS/" 2>/dev/null || true

echo "Dumping completed successfully into $BACKUP_DIR!"
