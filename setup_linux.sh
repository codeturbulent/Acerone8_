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
echo "[1/6] Creating workspace directories..."
mkdir -p tools
mkdir -p tablet_backup/STOCK_ORIGINALS
echo "  ✓ Directories created: tools/, tablet_backup/STOCK_ORIGINALS/"

# 2. Package manager detection & dependency check
echo "[2/6] Checking required system packages..."
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

# 3. Android Platform-Tools (check or download if adb/fastboot missing)
if ! command -v adb &>/dev/null || ! command -v fastboot &>/dev/null; then
    if [ ! -f "tools/platform-tools/adb" ]; then
        echo "[3/6] Downloading Android SDK Platform-Tools for Linux..."
        curl -L -o tools/platform-tools.zip "https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
        unzip -q -o tools/platform-tools.zip -d tools/
        rm -f tools/platform-tools.zip
        echo "  ✓ Platform-Tools extracted to tools/platform-tools"
    fi
    export PATH="$SCRIPT_DIR/tools/platform-tools:$PATH"
else
    echo "[3/6] System adb and fastboot detected."
fi

# 4. Clone or update mtkclient
echo "[4/6] Setting up mtkclient..."
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
echo "[5/6] Setting up Python virtual environment..."
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
echo "[6/6] Configuring udev rules & USB access..."
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
EOF
chmod +x dump_linux.sh

echo ""
echo "=================================================================="
echo "🎉 Linux setup is complete!"
echo "To dump your tablet partitions, run:"
echo "    ./dump_linux.sh"
echo "=================================================================="
