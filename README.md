# 🔓 Acer One 8 (T4-82L Gen 2) Root, Zero-Touch / MDM Bypass & GSI Guide

[![GitHub Repo](https://img.shields.io/badge/GitHub-codeturbulent%2FAcerone8__-blue?logo=github)](https://github.com/codeturbulent/Acerone8_)
[![Device](https://img.shields.io/badge/Device-Acer%20One%208%20(T4--82L--G2)-green?logo=android)](https://github.com/codeturbulent/Acerone8_)
[![Chipset](https://img.shields.io/badge/SoC-MediaTek%20Helio%20G85%20(MT6768%2FMT6769)-orange)](https://github.com/codeturbulent/Acerone8_)
[![Magisk](https://img.shields.io/badge/Root-Magisk%20v31.1-red?logo=magisk)](https://github.com/topjohnwu/Magisk)
[![MDM Status](https://img.shields.io/badge/MDM%20%2F%20Zero--Touch-Permanently%20Defeated-brightgreen)](#-defeating-the-tectoro-pvt-ltd--google-zero-touch-lock)

> **The definitive, tested guide to factory resetting, low-level partition dumping, fixing MTK Preloader bugs, unlocking bootloader, rooting with Magisk (GKI), bypassing institutional Zero-Touch/MDM locks ("Your device at work" / Tectoro), and flashing LineageOS GSI ROMs on the Acer One 8 (T4-82L Gen 2).**

---

## 📑 Table of Contents
1. [Device Architecture & Profile](#-device-architecture--profile)
2. [Key Discoveries & Low-Level Fixes](#-key-discoveries--low-level-fixes)
3. [Step 1: Hardware Factory Reset (MediaTek Factory Mode)](#step-1-hardware-factory-reset-mediatek-factory-mode)
4. [Step 2: Bootloader Unlock](#step-2-bootloader-unlock)
5. [Step 3: Zero-Risk Partition Dump via mtkclient](#step-3-zero-risk-partition-dump-via-mtkclient)
6. [Step 4: GKI Magisk Patching](#step-4-gki-magisk-patching)
7. [Step 5: Flashing via Fastboot](#step-5-flashing-via-fastboot)
8. [Step 6: Defeating "Your device at work" / Tectoro Zero-Touch Lock](#-defeating-the-tectoro-pvt-ltd--google-zero-touch-lock)
9. [Step 7: Flashing LineageOS / Custom GSI ROMs](#-flashing-lineageos--custom-gsi-roms)
10. [Emergency Unbrick Failsafe](#-emergency-unbrick-failsafe)

---

## 📱 Device Architecture & Profile

| Property | Value / Specification |
| :--- | :--- |
| **Model Name** | Acer One 8 (T4-82L-G2) |
| **Board / Platform** | `tb8786p1_64_k66` |
| **Processor (SoC)** | MediaTek MT6768 / MT6769 (Helio P65 / Helio G85 k68v1) |
| **Partitioning Scheme** | A/B Dynamic Partitions (Slot `b` active) |
| **Android Architecture** | Android 14+ / Generic Kernel Image (GKI Kernel v4) |
| **Ramdisk Location** | `init_boot` partition (NOT inside `boot`) |
| **Target Build Discovered** | `Acer_20261021` (Custom OEM / Educational distribution build) |
| **Distribution Context** | Widely distributed under student empowerment schemes (DgShakti / UP Government / Tectoro Pvt Ltd) |

---

## 🔍 Key Discoveries & Low-Level Fixes

### 1. Missing "Wipe Data / Factory Reset" in Recovery
Institutional builds remove the standard recovery wipe option to prevent MDM removal. Fastboot wipe (`fastboot -w`) is blocked in locked state.
- **The Solution:** MediaTek Factory Mode (`Power + Volume Down`) contains an engineering menu with **`Clear Storage`** (or `Clear eMMC`).

### 2. The Custom Build Danger (`Acer_20261021`)
Flashing random stock ROMs from the internet causes bootloops, broken Wi-Fi, or unresponsive touchscreens due to kernel/touch module mismatches.
- **The Solution:** Always dump the tablet's **exact live partitions** directly over USB before flashing anything.

### 3. MediaTek Helio G85 Preloader Bugs & Fixes
When dumping partitions with `mtkclient`, modern Helio G85 preloaders trigger two crashes:
- **Watchdog Register Lock (`USBError 5`):** Use `--skipwdt` and wrap the watchdog write in `try...except` in `mtk_preloader.py`.
- **Missing 4-Byte MEID Crash (`struct.error: unpack requires a buffer of 4 bytes`):** Modern preloaders return 0 bytes for MEID. The script must check buffer length (`len(buf) == 4`) before unpacking.

---

## 🛠️ Step-by-Step Walkthrough

### Step 1: Hardware Factory Reset (MediaTek Factory Mode)
1. Power the tablet completely **OFF**.
2. Press and hold **Power + Volume Down**.
3. Release both keys when the Chinese/English test menu appears.
4. Use **Volume Down** to navigate to **Clear Storage**.
5. Press the **Power button** (or Volume Up) to confirm. The tablet formats and reboots fresh.

---

### Step 2: Bootloader Unlock
1. Go through initial offline setup (do NOT connect to Wi-Fi yet).
2. In **Settings > About tablet**, tap **Build number** 7 times.
3. In **Settings > System > Developer options**:
   - Toggle **OEM unlocking** -> ON.
   - Toggle **USB debugging** -> ON.
4. Connect to PC and reboot to Fastboot:
   ```bash
   adb reboot bootloader
   ```
5. Unlock bootloader:
   ```bash
   fastboot flashing unlock
   ```
6. Press **Volume Up** on the tablet to confirm. Check unlock status:
   ```bash
   fastboot getvar unlocked
   # Result: unlocked: yes
   ```
7. Reboot:
   ```bash
   fastboot reboot
   ```

---

### Step 3: Zero-Risk Partition Dump via mtkclient
1. Clone `mtkclient` and install dependencies:
   ```bash
   git clone https://github.com/bkerler/mtkclient
   cd mtkclient
   python3 -m venv .venv && source .venv/bin/activate
   pip install pycryptodomex pyusb pyserial colorama
   ```
2. Run the dump script:
   ```bash
   sudo ./scripts/dump_backup.sh
   ```
3. When prompted, connect the powered-off tablet without pressing any buttons.
4. The tool dumps `boot_b.img`, `init_boot_b.img`, and `vbmeta_b.img` into `tablet_backup/`.
5. Keep an untouched copy in `tablet_backup/STOCK_ORIGINALS/`.

---

### Step 4: GKI Magisk Patching
*Because this device uses GKI architecture, you must patch `init_boot`, NOT `boot`.*

1. Push `init_boot_b.img` to the tablet:
   ```bash
   adb push tablet_backup/init_boot_b.img /sdcard/Download/init_boot.img
   ```
2. Install the latest [Magisk v31.1+ APK](https://github.com/topjohnwu/Magisk/releases):
   ```bash
   adb install -r Magisk.apk
   ```
3. Open Magisk on the tablet:
   - Tap **Install** > **Select and Patch a File**.
   - Select `/sdcard/Download/init_boot.img`.
   - Tap **LET'S GO!**.
4. Pull the patched file back to your PC:
   ```bash
   adb pull /sdcard/Download/magisk_patched-*.img tablet_backup/magisk_patched.img
   ```

---

### Step 5: Flashing via Fastboot
1. Reboot to bootloader:
   ```bash
   adb reboot bootloader
   ```
2. Flash the patched image:
   ```bash
   fastboot flash init_boot_b tablet_backup/magisk_patched.img
   fastboot reboot
   ```
3. Verify root via ADB:
   ```bash
   adb shell "su -c id"
   # Expected output:
   # uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
   ```

---

## 🛡️ Defeating the "Tectoro Pvt Ltd" / Google Zero-Touch Lock

### What happens when connecting to Wi-Fi:
The tablet's IMEI is registered to an enterprise portal (**Tectoro Pvt Ltd**). When Google Play Services (GMS) connects to the internet, it receives a Zero-Touch payload commanding it to install Android Device Policy and force a wipe countdown (*"Your device will automatically reset in 1 hour 55 minutes"*).

### How to permanently destroy this lock:

Run our automated script:
```bash
./scripts/block_mdm.sh
```

Or execute directly via ADB root:

1. **Disable Zero-Touch Factory Reset & Network Tasks in Google Play Services:**
   ```bash
   adb shell "su -c 'pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity'"
   adb shell "su -c 'pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService'"
   ```

2. **Make the Zero-Touch Configuration File Immutable:**
   ```bash
   adb shell "su -c 'echo -n \"\" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml'"
   adb shell "su -c 'chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml'"
   adb shell "su -c 'chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml'"
   ```
   *The `+i` (immutable) attribute prevents even Google Play Services or system services from ever writing a reset command or token again.*

3. **Disable Android Enterprise Managed Provisioning & Vendor OTA:**
   ```bash
   adb shell "su -c 'pm disable com.android.managedprovisioning; pm disable-user --user 0 com.android.managedprovisioning'"
   adb shell "su -c 'pm disable com.chipc.update; pm disable-user --user 0 com.chipc.update'"
   ```

4. **Firewall DeviceLockController at Kernel Level:**
   ```bash
   DLC_UID=$(adb shell "pm list packages -U | grep com.android.devicelockcontroller | sed -n 's/.*uid://p'")
   adb shell "su -c 'iptables -I OUTPUT -m owner --uid-owner $DLC_UID -j DROP; ip6tables -I OUTPUT -m owner --uid-owner $DLC_UID -j DROP'"
   ```

5. **Install Persistent Magisk Boot Service:**
   The script in `scripts/block_mdm.sh` automatically installs `/data/adb/service.d/block_mdm.sh` so these protections run on every boot!

---

## ⚡ Flashing LineageOS / Custom GSI ROMs

Because the tablet supports **Project Treble** and **Dynamic Partitions**, you can flash pure LineageOS GSIs without compiling from source:

1. Download an **ARM64 A/B GSI** (e.g. [AndyCGYan's LineageOS GSI](https://github.com/AndyCGYan/lineage_build_unified/releases) - look for `arm64_bgN` with GApps or `arm64_bvN` vanilla).
2. Extract the file to get `system.img`.
3. Reboot to **Fastbootd** (Userspace Fastboot):
   ```bash
   adb reboot fastboot
   ```
4. Flash system image and format:
   ```bash
   fastboot flash system system.img
   fastboot -w
   fastboot reboot
   ```

---

## 🛟 Emergency Unbrick Failsafe

If the device ever bootloops, restore the original untouched stock images in seconds:

```bash
fastboot flash init_boot_b tablet_backup/STOCK_ORIGINALS/init_boot_b.img
fastboot flash boot_b tablet_backup/STOCK_ORIGINALS/boot_b.img
fastboot reboot
```

---

## 🌟 Sharing & Contributing
If this guide helped you recover or free your tablet, please give it a **⭐ Star** on GitHub and share the link in student and Android forums!

- **Repository:** [https://github.com/codeturbulent/Acerone8_](https://github.com/codeturbulent/Acerone8_)
- **Keywords:** Acer One 8, T4-82L, DgShakti Tablet, Tectoro Pvt Ltd, Swami Vivekananda Yuva Sashaktikaran Yojana, UP Free Tablet Yojana, MT6768, Helio G85, Zero-Touch Bypass, Magisk Root GKI.
