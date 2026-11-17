# 🔓 Acer One 8 (T4-82L Gen 2) Root, Zero-Touch / MDM Bypass & GSI Guide

[![GitHub Repo](https://img.shields.io/badge/GitHub-codeturbulent%2FAcerone8__-blue?logo=github)](https://github.com/codeturbulent/Acerone8_)
[![Device](https://img.shields.io/badge/Device-Acer%20One%208%20(T4--82L--G2)-green?logo=android)](https://github.com/codeturbulent/Acerone8_)
[![Chipset](https://img.shields.io/badge/SoC-MediaTek%20Helio%20G85%20(MT6768%2FMT6769)-orange)](https://github.com/codeturbulent/Acerone8_)
[![Magisk](https://img.shields.io/badge/Root-Magisk%20v31.1-red?logo=magisk)](https://github.com/topjohnwu/Magisk)
[![YouTube Video](https://img.shields.io/badge/YouTube-Video%20Guide-red?logo=youtube)](https://www.youtube.com/watch?v=vdDfN86wU0I)
[![MDM Status](https://img.shields.io/badge/MDM%20%2F%20Zero--Touch-Permanently%20Defeated-brightgreen)](#-defeating-the-tectoro-pvt-ltd--google-zero-touch-lock)

> **The definitive, tested guide to factory resetting, low-level partition dumping, fixing MTK Preloader bugs, unlocking bootloader, rooting with Magisk (GKI), bypassing institutional Zero-Touch/MDM locks ("Your device at work" / Tectoro), and flashing LineageOS GSI ROMs on the Acer One 8 (T4-82L Gen 2).**

---

## 📺 Video Walkthrough
[![Acer One 8 Root & Zero-Touch Bypass Video Guide](https://img.youtube.com/vi/vdDfN86wU0I/maxresdefault.jpg)](https://www.youtube.com/watch?v=vdDfN86wU0I)

> 📹 **Watch the real-time recording and walkthrough on YouTube:**  
> 👉 [https://www.youtube.com/watch?v=vdDfN86wU0I](https://www.youtube.com/watch?v=vdDfN86wU0I)

---

## 📑 Table of Contents
0. [📺 Video Walkthrough](#-video-walkthrough)
1. [Step 0: One-Click Environment Setup (Fresh PC: Windows & Linux)](#step-0-one-click-environment-setup-fresh-pc-windows--linux)
2. [End-to-End Workflow Diagram](#-end-to-end-workflow-diagram)
3. [Device Architecture & Profile](#-device-architecture--profile)
4. [Key Discoveries & Low-Level Fixes](#-key-discoveries--low-level-fixes)
5. [Step 1: Hardware Factory Reset (MediaTek Factory Mode)](#step-1-hardware-factory-reset-mediatek-factory-mode)
6. [Step 2: Bootloader Unlock](#step-2-bootloader-unlock)
7. [Step 3: Zero-Risk Partition Dump via mtkclient](#step-3-zero-risk-partition-dump-via-mtkclient)
8. [Step 4: Downloading & Patching with Magisk v31+](#step-4-downloading--patching-with-magisk-v31)
9. [Step 5: Flashing via Fastboot](#step-5-flashing-via-fastboot)
10. [Step 6: Defeating "Your device at work" / Tectoro Zero-Touch Lock](#-defeating-the-tectoro-pvt-ltd--google-zero-touch-lock)
11. [Step 7: Flashing LineageOS / Custom GSI ROMs](#-flashing-lineageos--custom-gsi-roms)
12. [Emergency Unbrick Failsafe](#-emergency-unbrick-failsafe)

---

## 🗺️ End-to-End Workflow Diagram

```mermaid
flowchart TD
    A["Tablet Powered Off"] --> B["Hardware Factory Reset<br/>(Factory Mode -> Clear Storage)"]
    B --> C["Unlock Bootloader in Fastboot<br/>(fastboot flashing unlock)"]
    C --> D["Preloader Dump via mtkclient<br/>(boot_b.img, init_boot_b.img, vbmeta_b.img)"]
    D --> E["Save Untouched Stock Originals<br/>(Failsafe in STOCK_ORIGINALS/)"]
    E --> F["Push init_boot_b.img to Tablet via ADB"]
    F --> G["Download & Install Magisk v31+ APK"]
    G --> H["Patch init_boot.img in Magisk App<br/>(Produces magisk_patched.img)"]
    H --> I["Pull Patched Image to PC via ADB"]
    I --> J["Flash Patched init_boot via Fastboot<br/>(fastboot flash init_boot_b magisk_patched.img)"]
    J --> K["Reboot & Verify Full Root (su)"]
    K --> L["Neutralize Zero-Touch / Tectoro MDM<br/>(Run ./block_mdm.sh)"]
    L --> M["🎉 Safe Personal Tablet with Root!"]
```

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

> [!CAUTION]
> ### ⚠️ CRITICAL RULE: DO NOT CONNECT TO WI-FI / INTERNET YET!
> On institutional tablets, the device's IMEI and serial number are registered with **Google Zero-Touch Enrollment**. Connecting to Wi-Fi before rooting will immediately trigger Google Play Services to download the management profile and lock your tablet with a wipe countdown.
> 
> - **After 1st Reset (Factory Mode):** Skip the internet setup ("Set up offline" / "Skip").
> - **After 2nd Reset (Bootloader Unlock):** Skip the internet setup again ("Set up offline" / "Skip").
> - **Keep Wi-Fi OFF** until you have completed **Step 6 (`./block_mdm.sh`)**.

### Step 0: One-Click Environment Setup (Fresh PC: Windows & Linux)
Whether you are on a fresh Windows machine or Linux, you do not need to hunt down drivers, Python packages, or exploit repositories manually. The setup script configures everything in one go.

#### 1. Clone or Download This Repository
```bash
git clone https://github.com/codeturbulent/Acerone8_.git
cd Acerone8_
```
*(On Windows without Git: Click **Code > Download ZIP** on GitHub and extract the folder).*

---

#### 2. Run the Automated Setup

##### 🪟 Windows Setup:
Double-click **`setup_windows.bat`** (or right-click **`setup_windows.ps1`** -> **Run with PowerShell**).

> **What `setup_windows.bat` / `setup_windows.ps1` does automatically:**
> - Detects if Python or Git are missing and installs them automatically (via **winget** or **Scoop**).
> - Downloads **Android SDK Platform-Tools** (`adb` & `fastboot`) into `tools/platform-tools/`.
> - Downloads **Google Windows USB Drivers** into `tools/drivers/usb_driver/`.
> - Downloads **Zadig 2.9** driver installer into `tools/zadig-2.9.exe`.
> - Clones **mtkclient** into `tools/mtkclient/` and automatically applies the modified **`mtk_preloader.py`** (eliminating the Helio G85 buffer crash).
> - Creates a dedicated Python virtual environment (`.venv`) with all required libraries (`pycryptodomex`, `pyusb`, `pyserial`, `colorama`).

##### 🐧 Linux Setup:
Open a terminal inside the cloned folder and run:
```bash
chmod +x setup_linux.sh && ./setup_linux.sh
```
> **What `setup_linux.sh` does automatically:**
> - Installs missing distro packages (`python3`, `pip`, `venv`, `git`, `libusb`, `android-tools`).
> - Downloads `mtkclient` into `tools/mtkclient/` and applies the patched `mtk_preloader.py`.
> - Configures the Python virtual environment with `pycryptodomex` and `pyusb`.
> - Installs `udev` rules (`/etc/udev/rules.d/51-edl.rules`) and stops `ModemManager` port conflicts.

---

#### 3. Windows Driver Setup via Zadig (Required ONCE for MediaTek BROM / Preloader)
Windows requires the **libusb-win32** driver to communicate with MediaTek devices in low-level bootrom mode:
1. Open **`tools\zadig-2.9.exe`**.
2. Click **Options > List All Devices**.
3. Turn **OFF** your tablet.
4. Hold **BOTH Volume Up + Volume Down** (no Power button) and plug in the USB cable to your PC.
5. In Zadig's top dropdown list, quickly select **`MediaTek PreLoader USB VCOM Port`** or **`MTK USB Port`** (Hardware ID: `VID 0E8D`).
6. In the target driver box (green arrow), select **`libusb-win32`** (or **`WinUSB`**).
7. Click **Replace Driver** (or **Install Driver**). Once complete, Windows is 100% ready for partition dumping!

> [!TIP]
> If your device shows an exclamation mark in Windows Device Manager during Fastboot or ADB, right-click it, choose **Update Driver > Browse my computer**, and select **`tools\drivers\usb_driver`** (Google USB Driver).

---

### Step 1: Hardware Factory Reset (MediaTek Factory Mode)
1. Power the tablet completely **OFF**.
2. Press and hold **Power + Volume Down**.
3. Release both keys when the Chinese/English test menu appears.
4. Use **Volume Down** to navigate to **Clear Storage**.
5. Press the **Power button** (or Volume Up) to confirm. The tablet formats and reboots fresh.
6. **Setup Wizard (1st Reset):** When the Android setup wizard appears, select **"Set up offline"** (or **Skip**). **DO NOT connect to Wi-Fi.**

---

### Step 2: Bootloader Unlock
1. In the offline Android interface, open **Settings > About tablet** and tap **Build number** 7 times.
2. In **Settings > System > Developer options**:
   - Toggle **OEM unlocking** -> ON.
   - Toggle **USB debugging** -> ON.
3. Connect to PC and reboot to Fastboot:
   ```bash
   adb reboot bootloader
   ```
4. Unlock bootloader:
   ```bash
   fastboot flashing unlock
   ```
5. Press **Volume Up** on the tablet to confirm. Check unlock status:
   ```bash
   fastboot getvar unlocked
   # Result: unlocked: yes
   ```
6. Reboot the tablet:
   ```bash
   fastboot reboot
   ```
7. **Setup Wizard (2nd Reset):** Unlocking the bootloader automatically factory resets the tablet a second time. When the setup wizard appears, again choose **"Set up offline"** / **Skip**. **DO NOT connect to Wi-Fi.**
8. Re-enable **USB debugging** in Developer options so ADB can communicate with the tablet.

---

### Step 3: Zero-Risk Partition Dump via mtkclient
*Do not skip this step! Dumping your tablet's exact live partitions is your 100% guarantee against bricking.*

#### Method A: 1-Click Automated Dump (Recommended)
- **On Windows:** Double-click **`dump_windows.bat`** (or run `.\dump_windows.ps1` in PowerShell).
- **On Linux:** Open a terminal and run:
  ```bash
  ./dump_linux.sh
  ```

#### Method B: Manual Command Line Dump
If you prefer running the command directly in your terminal from the `Acerone8_` root folder:

- **On Windows (Command Prompt / PowerShell):**
  ```cmd
  tools\mtkclient\.venv\Scripts\python.exe tools\mtkclient\mtk.py r boot_b,init_boot_b,vbmeta_b tablet_backup\boot_b.img,tablet_backup\init_boot_b.img,tablet_backup\vbmeta_b.img --skipwdt
  ```

- **On Linux:**
  ```bash
  sudo tools/mtkclient/.venv/bin/python3 tools/mtkclient/mtk.py r boot_b,init_boot_b,vbmeta_b tablet_backup/boot_b.img,tablet_backup\init_boot_b.img,tablet_backup/vbmeta_b.img --skipwdt
  ```

> [!IMPORTANT]
> **Why `sudo tools/mtkclient/.venv/bin/python3` on Linux?**
> Running `sudo python3` strips virtual environment paths and invokes the system Python, triggering `ModuleNotFoundError: No module named 'Cryptodome'`. Calling the specific venv python path preserves all dependencies.

#### Connecting the Tablet for Dumping:
1. Power OFF your tablet completely.
2. When the terminal prompts `Waiting for PreLoader VCOM, please reconnect mobile/iot device to brom mode`:
   - Press and hold **BOTH Volume Up + Volume Down** (no Power button).
   - Plug in the USB cable to your PC while continuing to hold both buttons.
3. The script will detect the device in regular/brom mode:
   - `CPU: MT6768/MT6769(Helio P65/G85 k68v1)`
   - Keep the tablet still while it dumps `boot_b`, `init_boot_b`, and `vbmeta_b`.
4. Once completed, the dumped images are saved in `tablet_backup/` and immutable copies are automatically archived in `tablet_backup/STOCK_ORIGINALS/`!

---

### Step 4: Downloading & Patching with Magisk v31+
*Because this device uses modern Android GKI (Generic Kernel Image) architecture, you must patch `init_boot`, NOT `boot`.*

#### 1. Push the Stock `init_boot_b.img` to Tablet
Make sure your tablet is powered ON, USB Debugging is enabled, and it is connected via USB:
```bash
adb push tablet_backup/init_boot_b.img /sdcard/Download/init_boot.img
```

#### 2. Download & Install Magisk v31+ Directly
Download the latest official Magisk APK using `curl` and install it onto your tablet:
```bash
curl -L -o tablet_backup/Magisk.apk "https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk"
adb install -r tablet_backup/Magisk.apk
```

#### 3. Patch `init_boot.img` Inside the Magisk App
1. Open the newly installed **Magisk** app on your tablet screen.
2. In the top card (next to **Magisk**), tap **Install**.
3. Under **Method**, select **"Select and Patch a File"**.
4. A file picker will open:
   - Navigate to your **Downloads** folder.
   - Tap on **`init_boot.img`**.
5. Tap **LET'S GO!** in the top right corner.
6. Magisk will unpack, hook, and repack the ramdisk. In a few seconds, it will print:
   ```
   Output file is written to /storage/emulated/0/Download/magisk_patched-xxxx_xxxxx.img
   - All done!
   ```

#### 4. Pull the Patched Image to Your PC
Because `adb pull` does not expand remote wildcards, use the command for your OS:

- **On Linux / macOS:**
  ```bash
  PATCHED_FILE=$(adb shell "ls /sdcard/Download/magisk_patched-*.img" | tr -d '\r')
  adb pull "$PATCHED_FILE" tablet_backup/magisk_patched.img
  ```

- **On Windows (PowerShell):**
  ```powershell
  $PATCHED_FILE = (adb shell "ls /sdcard/Download/magisk_patched-*.img").Trim()
  adb pull "$PATCHED_FILE" tablet_backup/magisk_patched.img
  ```

- **On Windows (Command Prompt):**
  ```cmd
  for /f "tokens=*" %i in ('adb shell "ls /sdcard/Download/magisk_patched-*.img"') do adb pull "%i" tablet_backup/magisk_patched.img
  ```

*You now have `magisk_patched.img` saved in `tablet_backup/` ready for flashing!*

---

### Step 5: Flashing Patched Image via Fastboot
1. Reboot the tablet into bootloader (Fastboot mode):
   ```bash
   adb reboot bootloader
   ```
2. Flash the patched image into the active `init_boot` slot (`init_boot_b`):
   ```bash
   fastboot flash init_boot_b tablet_backup/magisk_patched.img
   ```
3. Reboot the tablet into Android:
   ```bash
   fastboot reboot
   ```
4. **Finalize Magisk Setup:**
   - Once Android boots, open the **Magisk** app.
   - If Magisk asks: *"Requires Additional Setup. Do you want to proceed?"*, tap **OK** (it will perform a quick 5-second reboot to finalize its environment).
5. **Verify Full Root Access:**
   Open a terminal on your computer and test `su`:
   ```bash
   adb shell "su -c id"
   # Output:
   # uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
   ```
   *(Grant the superuser prompt on the tablet screen if prompted).*

   - **Magisk Version:** `31.1:MAGISK:R`
   - **Root Context:** Unrestricted Magisk SELinux domain (`u:r:magisk:s0`).
   **Congratulations! Your tablet is now 100% rooted!**

---

## 🛡️ Defeating the "Tectoro Pvt Ltd" / Google Zero-Touch Lock

### What happens when connecting to Wi-Fi:
The tablet's IMEI is registered to an enterprise portal (**Tectoro Pvt Ltd**). When Google Play Services (GMS) connects to the internet, it receives a Zero-Touch payload commanding it to install Android Device Policy and force a wipe countdown (*"Your device will automatically reset in 1 hour 55 minutes"*).

### How to permanently destroy this lock:

#### Option 1: Run the Automated Script (Easiest & Recommended)
With your tablet rooted, powered on, and connected to your PC with USB debugging enabled, simply run:

```bash
./block_mdm.sh
```

#### Option 2: Run Directly in Terminal via ADB
Here is the clean, easy step-by-step guide to permanently blocking Zero-Touch enrollment and MDM on your tablet.

---

### Step 1: Open ADB Shell and Get Root

Connect your tablet to your PC with USB debugging enabled, open your terminal (Command Prompt or PowerShell), and elevate to root:

```bash
adb shell
su

```

*Verification:* Your terminal prompt changes from `$` to `#`.

---

### Step 2: Disable MDM & Zero-Touch Services

Copy and paste this command block into your root shell to disable the enrollment packages:

```bash
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService
pm disable com.android.managedprovisioning
pm disable com.chipc.update

```

*Verification:* Each command responds with `Package ... new state: disabled`.

---

### Step 3: Lock Down the Zero-Touch Config File

Clear out the Zero-Touch preferences file and lock it down so corporate servers can never write tokens to it again:

```bash
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n "" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi

```

*Verification:* The command completes silently without errors.

---

### Step 4: Apply the Kernel Firewall

Block the Device Lock Controller app from communicating with remote servers at the network level:

```bash
DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n "s/.*uid://p")
if [ -n "$DLC_UID" ]; then
    iptables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    echo "Firewall rules applied for UID: $DLC_UID"
fi

```

*Verification:* The terminal outputs `Firewall rules applied for UID: [number]`.

---

### Step 5: Install the Persistent Startup Script

Create a Magisk background service so these rules and locks re-apply automatically every time your device reboots:

```bash
mkdir -p /data/adb/service.d
cat << "EOF" > /data/adb/service.d/block_mdm.sh
#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
pm disable com.google.android.gms/.enterprise.zerotouch.ui.FactoryResetActivity >/dev/null 2>&1
pm disable com.google.android.gms/.enterprise.zerotouch.businesslogic.ZeroTouchGmsTaskService >/dev/null 2>&1
if [ -f /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml ]; then
    chattr -i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
    echo -n "" > /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chmod 444 /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml
    chattr +i /data/data/com.google.android.gms/shared_prefs/zero_touch_prefs.xml 2>/dev/null
fi
pm disable com.android.managedprovisioning >/dev/null 2>&1
pm disable com.chipc.update >/dev/null 2>&1
DLC_UID=$(pm list packages -U | grep com.android.devicelockcontroller | sed -n "s/.*uid://p")
if [ -n "$DLC_UID" ]; then
    iptables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
    ip6tables -C OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$DLC_UID" -j DROP
fi
rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
EOF

chmod 755 /data/adb/service.d/block_mdm.sh

```

*Verification:* Run `cat /data/adb/service.d/block_mdm.sh` to ensure the script contents display properly.

---

You are completely done! You can now turn on Wi-Fi and reboot your tablet safely.
> [!TIP]
> **Now it is 100% safe to connect to Wi-Fi / Internet!** Your tablet is completely liberated.

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
