# Comprehensive Root & Unbrick Guide: Acer One 8 (T4-82L Gen 2)

> **Complete guide to factory resetting, dumping firmware partitions via MediaTek BootROM (BROM), fixing mtkclient bugs on Helio G85, unlocking bootloader, patching with Magisk, and removing institutional Device Admin / MDM locks.**

---

## 📱 Hardware & Device Profile

| Property | Value / Specification |
| :--- | :--- |
| **Model Name** | Acer One 8 (T4-82L-G2) |
| **Board / Platform** | `tb8786p1_64_k66` |
| **Processor (SoC)** | MediaTek MT6768 / MT6769 (Helio P65 / Helio G85 k68v1) |
| **Storage Architecture** | eMMC (`CBHACG`, 64GB) |
| **Active Slot Configuration** | A/B Partitioning (Current active: Slot `b`) |
| **Android Architecture** | Android 14+ / Generic Kernel Image (GKI Kernel Header v4) |
| **Ramdisk Location** | `init_boot` partition (NOT inside `boot`) |
| **Firmware Build Discovered** | `Acer_20261021` (Custom OEM / Educational distribution build) |

---

## 🔍 Key Discoveries & Pitfalls Solved

### 1. The Missing "Wipe Data / Factory Reset" in Recovery
* **The Problem:** The standard stock Android recovery menu on this tablet **deliberately strips out** the "Wipe data / factory reset" option to prevent students/users from bypassing institutional enrollment.
* **The Fastboot Blocker:** Running `fastboot -w` or `fastboot erase userdata` failed with:
  ```
  FAILED (remote: 'not allowed in locked state')
  ```
* **The Solution:** MediaTek Factory Mode (`Power + Volume Down` key combination) has an engineering reset option titled **`Clear Storage`** (or `Clear eMMC`). Selecting this performs a clean hardware-level factory reset.

### 2. The Danger of Internet Stock ROMs
* The tablet runs custom build `Acer_20261021`. Flashing generic ROMs found on file archives often results in broken touchscreen, disabled Wi-Fi/Bluetooth, or hard bootloops due to kernel/module version mismatches.
* **The Safe Solution:** Extract the tablet's **exact live partitions** directly over USB using low-level MediaTek BootROM / Preloader mode before modifying anything.

### 3. MediaTek Helio G85 `mtkclient` Bugs & Patches
During partition dumping with `mtkclient`, two critical bugs were encountered on this modern SoC:
1. **Watchdog Register Lock (`USBError 5`):**
   * Modern MediaTek preloaders block host computers from modifying `SetReg_DisableWatchDogTimer`.
   * **Fix:** Use `--skipwdt` and wrap the watchdog register call with a `try...except` block in `mtk_preloader.py`.
2. **Missing 4-Byte MEID Crash (`struct.error`):**
   * Modern preloaders return 0 bytes when queried for legacy MEID IDs. `unpack(">I", self.usbread(4))` crashed with `struct.error: unpack requires a buffer of 4 bytes`.
   * **Fix:** Check buffer length (`len(buf) == 4`) before calling `unpack`.

---

## 🛠️ Step-by-Step Walkthrough

### Step 1: Factory Reset via MediaTek Factory Mode
1. Power the tablet completely **OFF**.
2. Press and hold **Power + Volume Down**.
3. Release the keys once the MediaTek test menu appears.
4. Use **Volume Down** to navigate to **Clear Storage**.
5. Press the **Power button** (or Volume Up) to confirm.
6. The storage will format, and the tablet will reboot fresh.

---

### Step 2: Unlock the Bootloader
1. Complete the initial Android offline setup.
2. Go to **Settings > About tablet** and tap **Build number** 7 times to enable Developer Options.
3. Open **Settings > System > Developer options**:
   - Enable **OEM unlocking**.
   - Enable **USB debugging**.
4. Connect the tablet to your PC and reboot to Fastboot:
   ```bash
   adb reboot bootloader
   ```
5. Unlock the bootloader:
   ```bash
   fastboot flashing unlock
   ```
6. Confirm the unlock on the tablet screen with the **Volume Up** button.
7. Verify the unlock status:
   ```bash
   fastboot getvar unlocked
   # Should report: unlocked: yes
   ```
8. Reboot back into Android:
   ```bash
   fastboot reboot
   ```

---

### Step 3: Zero-Risk Partition Dump via MediaTek Preloader
To guarantee safety against bricking, dump your live stock partitions (`boot_b`, `init_boot_b`, and `vbmeta_b`):

1. Install `mtkclient` and dependencies:
   ```bash
   git clone https://github.com/bkerler/mtkclient
   cd mtkclient
   python3 -m venv .venv
   source .venv/bin/activate
   pip install pycryptodomex pyusb pyserial colorama
   ```
2. Run the dump command:
   ```bash
   sudo python3 mtk.py r boot_b,init_boot_b,vbmeta_b \
       ../tablet_backup/boot_b.img,../tablet_backup/init_boot_b.img,../tablet_backup/vbmeta_b.img \
       --skipwdt
   ```
3. When prompted (`Waiting for PreLoader VCOM`):
   - Power off the tablet.
   - Plug the USB cable in **without pressing any buttons** (or hold **Volume Up** only).
4. The tool uploads the DA and dumps all partitions to `../tablet_backup/`.
5. **Keep an untouched copy** of these images in a safe folder as an immutable unbrick failsafe!

---

### Step 4: Patching with Magisk
Because this device uses Android Generic Kernel Image (GKI) architecture:
- `boot.img` contains only the Linux kernel.
- **`init_boot.img`** contains the ramdisk and must be patched.

1. Power on the tablet into Android with USB Debugging enabled.
2. Push `init_boot_b.img` to the tablet:
   ```bash
   adb push ../tablet_backup/init_boot_b.img /sdcard/Download/init_boot.img
   ```
3. Install the official Magisk APK (v31.1+):
   ```bash
   adb install -r Magisk.apk
   ```
4. Open the **Magisk** app on the tablet:
   - Tap **Install** (top card).
   - Choose **Select and Patch a File**.
   - Navigate to `/sdcard/Download/` and select **`init_boot.img`**.
   - Tap **LET'S GO!**.
5. Once it completes, pull the patched file back to your PC:
   ```bash
   adb pull /sdcard/Download/magisk_patched-*.img ../tablet_backup/magisk_patched.img
   ```

---

### Step 5: Flashing Patched Image via Fastboot
1. Reboot the tablet into bootloader:
   ```bash
   adb reboot bootloader
   ```
2. Flash the patched image to the active `init_boot` slot:
   ```bash
   fastboot flash init_boot_b ../tablet_backup/magisk_patched.img
   ```
3. Reboot into Android:
   ```bash
   fastboot reboot
   ```
4. Verify root status via ADB:
   ```bash
   adb shell "su -c id"
   # Output:
   # uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
   ```
   - **Magisk Version:** `31.1:MAGISK:R`
   - **Root Context:** Unrestricted Magisk SELinux domain (`u:r:magisk:s0`).

---

### Step 6: Removing Institutional Device Admin & Preventing Internet Auto-Enrollment (MDM)

On institutional / educational tablets (such as DgShakti / UP scheme), the moment you connect to Wi-Fi for the first time, Android contacts Google Zero-Touch and institutional servers to silently download the admin app and lock the device.

We completely neutralize this before connecting to the internet:

1. **Disable `ManagedProvisioning`:**
   ```bash
   pm disable com.android.managedprovisioning
   pm disable-user --user 0 com.android.managedprovisioning
   ```
   *`com.android.managedprovisioning` is the core Android system engine responsible for Zero-Touch enrollment and setting up Device Owners. With this disabled, Android cannot download or assign any Device Owner.*

2. **Disable Vendor OTA (`com.chipc.update`):**
   ```bash
   pm disable com.chipc.update
   pm disable-user --user 0 com.chipc.update
   ```
   *Disables background OEM updates to prevent remote configuration changes.*

3. **Firewall `DeviceLockController` (UID 10184):**
   ```bash
   iptables -I OUTPUT -m owner --uid-owner 10184 -j DROP
   ip6tables -I OUTPUT -m owner --uid-owner 10184 -j DROP
   ```
   *Adds kernel-level iptables rules that immediately drop any outgoing network packets from `com.android.devicelockcontroller`. Even if it tries to call home, all connection attempts are blocked.*

4. **Permanent Magisk Boot Guard:**
   Install a persistent startup service at `/data/adb/service.d/block_mdm.sh` on the tablet. It runs on every boot as root to enforce these rules, remove any policy files, and ensure the tablet remains 100% clean:
   ```bash
   adb shell "su -c 'cat << \"EOF\" > /data/adb/service.d/block_mdm.sh
   #!/system/bin/sh
   while [ \"\$(getprop sys.boot_completed)\" != \"1\" ]; do
       sleep 2
   done
   pm disable com.android.managedprovisioning >/dev/null 2>&1
   pm disable-user --user 0 com.android.managedprovisioning >/dev/null 2>&1
   pm disable com.chipc.update >/dev/null 2>&1
   pm disable-user --user 0 com.chipc.update >/dev/null 2>&1
   DLC_UID=\$(pm list packages -U | grep com.android.devicelockcontroller | sed -n \"s/.*uid://p\")
   if [ -n \"\$DLC_UID\" ]; then
       iptables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
       ip6tables -C OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner \"\$DLC_UID\" -j DROP
   fi
   rm -f /data/system/device_owner_2.xml /data/system/device_policies.xml
   EOF
   chmod 755 /data/adb/service.d/block_mdm.sh
   '"
   ```

---

### 🎉 Safe Internet Connection Achieved!
With the above steps completed, you can now safely connect to Wi-Fi and the Internet. The tablet will function as a standard personal Android tablet with zero management policies, zero restrictions, and full root access.

---

## 🛟 Emergency Recovery / Unbrick Failsafe

If you ever experience a bootloop or issue, restore the tablet to factory state in seconds using your original stock backup:

```bash
# If Fastboot is accessible:
fastboot flash init_boot_b ../tablet_backup/STOCK_ORIGINALS/init_boot_b.img
fastboot flash boot_b ../tablet_backup/STOCK_ORIGINALS/boot_b.img
fastboot reboot

# If device does not boot to Fastboot:
# Use mtkclient in BROM mode to re-flash the original partitions:
sudo python3 mtk.py w init_boot_b,boot_b \
    ../tablet_backup/STOCK_ORIGINALS/init_boot_b.img,../tablet_backup/STOCK_ORIGINALS/boot_b.img \
    --skipwdt
```

---

## 📄 License & Credits
- Created with [mtkclient](https://github.com/bkerler/mtkclient) by B. Kerler.
- Magisk by [topjohnwu](https://github.com/topjohnwu/Magisk).
