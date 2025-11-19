# meta-banapro

Yocto layer that reproduces the Banana Pro bring-up workflow previously handled by the `scripts/banapro/*.sh` helpers.

## Contents

- **Machine**: `bananapro` – inherits Allwinner A20 settings, enforces the Mesa GBM stack (instead of proprietary Mali blobs), and adds the 5" RGB LCD overlay.
- **U-Boot**: applies the 800x480 timing fragment automatically.
- **Kernel**: pulls in the local Banana Pro patches and builds the `bpi-m1p-lcd.dtbo` overlay.
- **Image**: `banapro-image` – Weston-capable rootfs with networking tools.

## Quick start

```bash
# Inside your poky checkout
bitbake-layers add-layer ../meta-sunxi
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-banapro

echo 'MACHINE = "bananapro"' >> conf/local.conf
# Optional but recommended
echo 'DISTRO = "banapro"' >> conf/local.conf

bitbake banapro-image
```

`tmp/deploy/images/bananapro/` will contain:

- `u-boot-sunxi-with-spl.bin` – flash to SD offset 8KiB (`dd if=... of=/dev/sdX bs=1024 seek=8`).
- `zImage`, `sun7i-a20-bananapro.dtb`, and `bpi-m1p-lcd.dtbo` – ready for `/boot`.
- SD card wic/bmap image when `wic` is enabled via `IMAGE_FSTYPES`.

## LCD configuration

The U-Boot fragment matches the values from `patches/banana_pro_5lcd.fex`:

```
CONFIG_VIDEO_LCD_MODE="x:800,y:480,depth:24,pclk_khz:30000,le:40,ri:40,up:29,lo:13,hs:48,vs:3,sync:3,vmode:0"
```

Run-time tweaks:

```bash
echo 'UBOOT_CONFIG_FLAGS:bananapro += "CONFIG_VIDEO_LCD_MODE=\"x:1024,y:600,...\""' >> conf/local.conf
```

Alternatively, edit `recipes-bsp/u-boot/u-boot-banapro/lcd.cfg` and rebuild.

## Next steps

- Extend `banapro-image.bb` with additional packages (GNOME, XFCE, etc.).
- Add CI to run `bitbake-layers show-layers && bitbake banapro-image`.
- Remove legacy shell scripts once the Yocto flow ships reproducible artifacts.
