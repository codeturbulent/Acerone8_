#!/usr/bin/env bash
set -e

# ==============================================================================
# Acer One 8 (T4-82L Gen 2) - Automated Environment Setup (Linux)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================================="
echo " 🚀 Acer One 8 - Environment & Dependency Setup (Linux)"
echo "=================================================================="

# 1. Create directory structure
echo "[1/7] Creating workspace directories..."
mkdir -p tools
mkdir -p tablet_backup/STOCK_ORIGINALS
echo "  ✓ Directories created: tools/, tablet_backup/STOCK_ORIGINALS/"

# 2. Package manager detection & dependency check
echo "[2/7] Checking required system packages..."
MISSING_PKGS=()
for cmd in python3 git; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "  ⚠️ Missing packages detected: ${MISSING_PKGS[*]}"
    if command -v apt-get &>/dev/null; then
        echo "  Installing via apt..."
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip python3-venv git libusb-1.0-0 android-tools-adb android-tools-fastboot
    elif command -v pacman &>/dev/null; then
        echo "  Installing via pacman..."
        sudo pacman -Sy --noconfirm python python-pip git libusb android-tools
    elif command -v dnf &>/dev/null; then
        echo "  Installing via dnf..."
        sudo dnf install -y python3 python3-pip git libusb1 android-tools
    else
        echo "  ❌ Unknown package manager. Please manually install python3, python3-venv, git, libusb, and android-tools."
        exit 1
    fi
else
    echo "  ✓ Base commands found: python3, git"
fi

# 3. Android Platform-Tools (ensure present in tools/platform-tools)
echo "[3/7] Setting up Android SDK Platform-Tools..."
if [ ! -f "tools/platform-tools/adb" ] || [ ! -f "tools/platform-tools/fastboot" ]; then
    echo "  Downloading Android SDK Platform-Tools for Linux..."
    PLATFORM_TOOLS_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
    if command -v curl &>/dev/null; then
        curl -fL --retry 3 --connect-timeout 15 -o tools/platform-tools.zip "$PLATFORM_TOOLS_URL" 2>/dev/null || \
        curl -k -fL -o tools/platform-tools.zip "$PLATFORM_TOOLS_URL"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O tools/platform-tools.zip "$PLATFORM_TOOLS_URL"
    else
        echo "  ❌ Neither curl nor wget found. Please install curl or wget."
        exit 1
    fi
    unzip -q -o tools/platform-tools.zip -d tools/
    rm -f tools/platform-tools.zip
    chmod +x tools/platform-tools/adb tools/platform-tools/fastboot 2>/dev/null || true
    echo "  ✓ Platform-Tools extracted to tools/platform-tools"
else
    echo "  ✓ Platform-Tools already present in tools/platform-tools"
fi

# 4. Clone or update mtkclient
echo "[4/7] Setting up mtkclient..."
if [ ! -d "tools/mtkclient/.git" ]; then
    echo "  Cloning mtkclient repository into tools/mtkclient..."
    rm -rf tools/mtkclient
    git clone --depth 1 https://github.com/bkerler/mtkclient tools/mtkclient
else
    echo "  ✓ mtkclient repository already exists."
fi

# Apply the modified mtk_preloader.py (Helio G85 MEID buffer length fix)
if [ -f "mtk_preloader.py" ]; then
    echo "  Patching tools/mtkclient with modified mtk_preloader.py..."
    cp -f mtk_preloader.py tools/mtkclient/mtkclient/Library/mtk_preloader.py
    echo "  ✓ mtk_preloader.py patch applied."
else
    echo "  ⚠️ Warning: mtk_preloader.py not found in root. Skipping patch."
fi

# 5. Configure Python virtual environment & install requirements
echo "[5/7] Setting up Python virtual environment..."
python3 -m venv tools/mtkclient/.venv
tools/mtkclient/.venv/bin/python3 -m pip install --upgrade pip --quiet
tools/mtkclient/.venv/bin/pip install --quiet pycryptodomex pyusb pyserial colorama

# Verify pycryptodomex import
if tools/mtkclient/.venv/bin/python3 -c "from Cryptodome.Cipher import AES; import usb.core" 2>/dev/null; then
    echo "  ✓ Python virtual environment ready (pycryptodomex & pyusb verified)."
else
    echo "  ❌ Failed to verify Python virtual environment packages."
    exit 1
fi

# 6. Configure Linux udev rules & ModemManager
echo "[6/7] Configuring udev rules & USB access..."
UDEV_FILE="/etc/udev/rules.d/51-edl.rules"
RULES_CONTENT='# MediaTek Preloader & BootROM
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", GROUP="plugdev"
# Google ADB & Fastboot
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"'

if [ ! -f "$UDEV_FILE" ]; then
    if sudo -n true 2>/dev/null; then
        echo "  Writing udev rules to $UDEV_FILE..."
        echo "$RULES_CONTENT" | sudo tee "$UDEV_FILE" >/dev/null
        sudo udevadm control --reload-rules 2>/dev/null || true
        sudo udevadm trigger 2>/dev/null || true
        echo "  ✓ udev rules installed."
    else
        echo "  ℹ️  To install udev rules for non-root USB access, run:"
        echo "     echo '$RULES_CONTENT' | sudo tee $UDEV_FILE"
        echo "     sudo udevadm control --reload-rules && sudo udevadm trigger"
    fi
else
    echo "  ✓ udev rules already present in $UDEV_FILE."
fi

# Stop ModemManager interference if running
if systemctl is-active --quiet ModemManager 2>/dev/null; then
    if sudo -n true 2>/dev/null; then
        echo "  Stopping ModemManager service to prevent serial port conflicts..."
        sudo systemctl stop ModemManager 2>/dev/null || true
        echo "  ✓ ModemManager stopped."
    else
        echo "  ℹ️  If ModemManager is active, stop it with: sudo systemctl stop ModemManager"
    fi
fi

# 7. Pre-download Magisk v31+ APK
echo "[7/7] Setting up Magisk root package..."
MAGISK_URL="https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk"
MAGISK_FILE="tablet_backup/Magisk.apk"
if [ ! -f "$MAGISK_FILE" ] || [ ! -s "$MAGISK_FILE" ]; then
    echo "  Downloading Magisk v31.1 APK into tablet_backup/Magisk.apk..."
    if command -v curl &>/dev/null; then
        curl -fL --retry 3 --connect-timeout 15 -o "$MAGISK_FILE" "$MAGISK_URL" 2>/dev/null || \
        curl -k -fL -o "$MAGISK_FILE" "$MAGISK_URL" 2>/dev/null || true
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$MAGISK_FILE" "$MAGISK_URL" 2>/dev/null || true
    fi
    if [ -f "$MAGISK_FILE" ] && [ -s "$MAGISK_FILE" ]; then
        echo "  ✓ Magisk v31.1 APK ready in tablet_backup/Magisk.apk"
    else
        echo "  ⚠️ Magisk APK download could not complete automatically (can be placed in tablet_backup/Magisk.apk manually)"
    fi
else
    echo "  ✓ Magisk v31.1 APK already present in tablet_backup/Magisk.apk"
fi

# Generate convenient dump_linux.sh runner script
cat << "EOF" > dump_linux.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "=========================================================="
echo " 🚀 Starting MediaTek Live Partition Dump"
echo " 1. Power OFF your tablet completely."
echo " 2. Hold BOTH Volume Up + Volume Down (no Power button)."
echo " 3. Plug in the USB cable while holding both buttons."
echo "=========================================================="

sudo tools/mtkclient/.venv/bin/python3 tools/mtkclient/mtk.py r \
    "boot_a,boot_b,init_boot_a,init_boot_b,vbmeta_a,vbmeta_b" \
    "tablet_backup/boot_a.img,tablet_backup/boot_b.img,tablet_backup/init_boot_a.img,tablet_backup/init_boot_b.img,tablet_backup/vbmeta_a.img,tablet_backup/vbmeta_b.img" \
    --skipwdt

if [ -f tablet_backup/boot_b.img ]; then
    cp -f tablet_backup/*.img tablet_backup/STOCK_ORIGINALS/
    echo ""
    echo "=========================================================="
    echo "🎉 SUCCESS: Partitions dumped and original stock copies"
    echo "safely archived in tablet_backup/STOCK_ORIGINALS/!"
    echo "=========================================================="
fi
EOF
chmod +x dump_linux.sh

echo ""
echo "=================================================================="
echo "🎉 Linux setup is complete!"
echo "To dump your tablet partitions, run:"
echo "    ./dump_linux.sh"
echo "=================================================================="
