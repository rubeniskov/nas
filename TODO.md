# Banana Pro (BPI-M1+) – Arch Linux ARM Bring-Up TODO

> Goal: reach “fully operative SBC” parity (or better) vs legacy Armbian 3.4 image.

---

## [ ] Graphics / Display / Desktop

- [ ] Ensure mainline DRM & GPU drivers are enabled:
  - [ ] `sun4i-drm`, `sun4i-drm-hdmi` (KMS for A20)
  - [ ] `lima` (Mali-400 GPU)
- [ ] Install userspace graphics stack:
  - [ ] `mesa`, `mesa-demos`, `weston`, `kmscube`, `xorg-server` (optional), `xf86-video-modesetting` (if using Xorg)
- [ ] Verify basic KMS:
  - [ ] Run `kmscube` on TTY to confirm 3D acceleration.
- [ ] Fix Weston DRM compositor:
  - [ ] `systemctl status weston-drm` → inspect errors
  - [ ] Create/adjust `/etc/xdg/weston/weston.ini` (backend, seat, tty)
  - [ ] Confirm `weston-drm` starts and shows a desktop on HDMI.

---

## [ ] On-Board Wi-Fi (AP6211)

- [ ] Enable mainline Broadcom SDIO driver:
  - [ ] Kernel config: `CONFIG_BRCMFMAC` (+ SDIO support) built-in or as module.
- [ ] Install firmware files:
  - [ ] `brcm/brcmfmac43362-sdio.bin`
  - [ ] Correct `nvram` file for AP6211 (often adapted `brcmfmac43362-sdio.*.txt`)
- [ ] Verify Device Tree:
  - [ ] Ensure DTB for Banana Pro has Wi-Fi SDIO node enabled (no `status = "disabled"`).
- [ ] Test in userspace:
  - [ ] `dmesg | grep brcmfmac`
  - [ ] Confirm `wlan0` exists (`ip link`)
  - [ ] Connect to AP using `iwd`, `wpa_supplicant` or `NetworkManager`.

---

## [ ] On-Board Bluetooth

- [ ] Enable kernel support:
  - [ ] `CONFIG_BT`, `CONFIG_BT_HCIUART`, and relevant protocol options (`HCIUART_3WIRE`, etc.).
- [ ] Verify DT for BT:
  - [ ] UART node marked as `bluetooth` with correct GPIOs for reset/power.
- [ ] Create attach service:
  - [ ] Use `btattach` or `hciattach` in a systemd unit to bring up `hci0`.
- [ ] Confirm operation:
  - [ ] `hciconfig -a`
  - [ ] `bluetoothctl` → power on, scan, pair with a device.

---

## [ ] IR Receiver (Remote Control)

- [ ] Enable IR driver:
  - [ ] Kernel: `CONFIG_IR_SUNXI` / corresponding mainline driver.
- [ ] Confirm DT node for IR (pin, protocol).
- [ ] Install tools:
  - [ ] `ir-keytable` / `v4l-utils`.
- [ ] Configure keymap:
  - [ ] Load appropriate `rc_keymap` or custom mapping.
  - [ ] Test with `ir-keytable -t`.

---

## [ ] LEDs & Board Indicators

- [ ] Confirm LED driver:
  - [ ] `leds-sunxi` (or equivalent mainline).
- [ ] Check sysfs:
  - [ ] `ls /sys/class/leds` → Banana Pro LEDs appear.
- [ ] Assign triggers:
  - [ ] Configure LED triggers (e.g. `cpu`, `mmc`, `heartbeat`) via sysfs or udev rules.

---

## [ ] CPU Frequency & Thermal

- [ ] Enable cpufreq:
  - [ ] `CONFIG_CPU_FREQ`, `CONFIG_CPUFREQ_DT` (or correct driver).
- [ ] Enable governors:
  - [ ] `ondemand`, `schedutil`, `performance`, etc.
- [ ] Check operation:
  - [ ] `cpufreq-info` / `cat /sys/devices/system/cpu/cpu0/cpufreq/*`
- [ ] Verify thermal zones:
  - [ ] `ls /sys/class/thermal` → temperature sensors available.
- [ ] Set sane defaults:
  - [ ] Use `cpupower` or udev/systemd to select governor.

---

## [ ] SATA & Mass Storage

- [ ] Verify AHCI driver:
  - [ ] `ahci-sunxi` / `ahci_platform` enabled in kernel.
- [ ] Connect SATA disk and check:
  - [ ] `dmesg | grep -i sata`
  - [ ] Confirm `/dev/sdX` appears and SMART works (`smartctl`).

---

## [ ] SPI / I²C for Peripherals

- [ ] Enable SPI & I²C controllers in DT:
  - [ ] Ensure nodes are `status = "okay"`.
- [ ] Expose devices:
  - [ ] Add `spidev` DT entries (or real device drivers).
- [ ] Confirm device files:
  - [ ] `ls /dev/spidev*`, `ls /dev/i2c-*`.
- [ ] Test bus:
  - [ ] `spi-tools` / `i2c-tools` (e.g. `i2cdetect`, etc.).

---

## [ ] Audio (Analog + HDMI)

- [ ] Enable codec drivers:
  - [ ] `sun4i-codec` / `sun7i-a20-codec`, `sun4i-i2s`, HDMI audio endpoints.
- [ ] Install ALSA utilities:
  - [ ] `alsa-utils` for `aplay`, `alsamixer`.
- [ ] Check devices:
  - [ ] `aplay -l` → analog + HDMI cards visible.
- [ ] Test sound:
  - [ ] Play WAV/OGG on analog out and HDMI, adjust mixer with `alsamixer`.

---

## [ ] Memory / Swap / ZRAM (Optional, but useful)

- [ ] Decide swap strategy:
  - [ ] ZRAM swap (recommended) or on-disk swap.
- [ ] For ZRAM:
  - [ ] Install `zram-generator` or create custom systemd zram unit.
  - [ ] Configure size (e.g. 512MB–1GB) and compression (zstd/lz4).
- [ ] Confirm active swap:
  - [ ] `swapon --show`.

---

## [ ] Automount / Autofs (Optional)

- [ ] Fix missing `autofs4` module:
  - [ ] Enable `CONFIG_AUTOFS_FS` or appropriate autofs module.
- [ ] Install `autofs` package if needed.
- [ ] Configure:
  - [ ] `/etc/autofs/auto.master` and maps for NFS/USB, etc.
- [ ] Verify:
  - [ ] Access mountpoints and check that automount kicks in.

---

## [ ] Composite TV-Out (If Needed)

- [ ] Check if mainline DT has TV encoder (`tve`) node enabled.
- [ ] Enable composite output via KMS if supported:
  - [ ] Add or tweak DT overlay for TV-out.
- [ ] Configure mode:
  - [ ] Use `modetest` / `kms` tools to set 576i/480i modes.
- [ ] Test image quality on analog TV input.

---

## [ ] Final Integration & Testing

- [ ] Confirm clean boot:
  - [ ] `dmesg` free of obvious errors (mmc, Wi-Fi, GPU, DRM).
- [ ] Network:
  - [ ] Ethernet + Wi-Fi up, BT working with at least one paired device.
- [ ] GUI:
  - [ ] Weston (or Xorg + DE) runs with hardware acceleration.
- [ ] Multimedia:
  - [ ] Video playback uses GPU where possible (and Cedrus/VAAPI if configured).
- [ ] Backup:
  - [ ] Create an image/backup of the working SD card (or rootfs snapshot).




## Some notes

pacman -Sy gnupg archlinuxarm-keyring --needed
pacman-key --init
pacman-key --populate archlinuxarm




pacman -S vim
pacman -S cloud-guest-utils

pacman -S mesa mesa-demos mesa-utils





pacman -S weston seatd wayland-utils glmark2
usermod -aG video,render,seat $USER
systemctl enable --now seatd.service
weston --backend=drm-backend.so --tty=1 --log=/tmp/weston.log

warning: warning given when extracting /usr/lib/gstreamer-1.0/gst-ptp-helper (Cannot restore extended attributes on this file system.)
Failed to set capabilities on file 'usr/lib/gstreamer-1.0/gst-ptp-helper': Operation not supported








// Test 
sudo pacman -S base-devel meson ninja git
git clone https://gitlab.freedesktop.org/mesa/kmscube.git
cd kmscube
meson setup build
ninja -C build
sudo ./build/kmscube
