You can automate the full Banana Pi M1+ Arch Linux build with:
```
./scripts/bpi-m1p-setup.sh
```

Automation helpers:
- `./scripts/banapro-build.sh` builds the mainline Banana Pro kernel (zImage, dtbs, modules, headers) and U-Boot as described in the Mainline Kernel Howto and U-Boot guide.
- `sudo ./scripts/create-arch-rootfs.sh /dev/sdX` provisions an Arch Linux ARM rootfs on the specified card/drive, mirroring the Arch install steps (set `ARCH_ROOTFS_URL`, `UBOOT_BIN_URL`, or `BOOTSCR_URL` to override defaults).

## Yocto / OpenEmbedded flow

The new `meta-banapro` layer mirrors the functionality of the legacy shell scripts while providing a reproducible Yocto build. Add it to your Poky workspace together with the required upstream layers and build the ready-to-flash image:

```
bitbake-layers add-layer \
	../meta-openembedded/meta-oe \
	../meta-openembedded/meta-python \
	../meta-arm/meta-arm-toolchain \
	../meta-arm/meta-arm \
	../meta-sunxi \
	../meta-banapro
echo 'MACHINE = "bananapro"' >> conf/local.conf
echo 'DISTRO = "banapro"' >> conf/local.conf  # optional distro tweaks
bitbake banapro-image
```

Artifacts (U-Boot, kernel, DTB, LCD overlay, and wic image) will be emitted under `tmp/deploy/images/bananapro/`.

The custom `banapro` distro forces the open-source Mesa GBM stack so Wayland/Weston can satisfy the `virtual/libgbm` dependency without the proprietary Mali blobs.

### Automated helper

To automate host dependency installation, Yocto repo checkout, layer registration, and the final `bitbake` invocation, run:

```
./scripts/yocto_build.sh
```

The helper tracks the Poky `scarthgap` release (including matching branches for `meta-openembedded`, `meta-sunxi`, and `meta-arm`) by default. Environment variables such as `YOCTO_DIR`, `YOCTO_BUILD_DIR`, `POKY_BRANCH`, `META_OE_BRANCH`, `META_SUNXI_BRANCH`, `META_ARM_BRANCH`, and `BITBAKE_IMAGE` let you customise the workspace location, build directory, upstream branches, and target image respectively.

Before calling `apt-get`, the helper probes which host packages are already installed so it only installs the missing ones.

### Makefile shortcuts

A lightweight `Makefile` in the repo root wraps the common workflows:

```bash
# Build the Yocto image (uses ./scripts/yocto_build.sh under the hood)
make build

# Flash the latest .wic image onto an SD card (requires bmaptool)
make flash SD_DEVICE=/dev/sdX
```

Variables such as `YOCTO_HELPER`, `YOCTO_BUILD_DIR`, `DEPLOY_DIR`, and `IMAGE_BASE` can be overridden if your workspace layout differs. The `flash` target checks that the `.wic.gz` image and `.wic.bmap` exist and refuses to run unless `SD_DEVICE` points to an actual block device. Remember that the operation will wipe the selected device entirely, so double-check the path before flashing.

## Additional Guides

- [TFTP Boot Configuration](docs/TFTP_BOOT_CONFIGURATION.md): Configure U-Boot to load kernel, DTBs, and rootfs from a TFTP server over the network
- [5-Inch LCD Configuration](docs/LCD_5INCH_CONFIGURATION.md): Configure the 5-inch LCD display

# References

- https://archlinuxarm.org/platforms/armv7/allwinner/cubietruck
- https://forum.armbian.com/topic/841-bananapro-lemaker-5in-lcd-legacy-kernel/
- https://github.com/LeMaker/fex_configuration/blob/master/README.md
- https://forum.armbian.com/topic/14560-sun4i-drm-and-lcd-panels/
- https://linux-sunxi.org/A20#DVFS
- https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/09_01_00_08/exports/docs/linux/How_to_Guides/Target/How_to_enable_DT_overlays_in_linux.html
- https://github.com/wens/dt-overlays/tree/master
- https://xnux.eu/howtos/install-arch-linux-arm.html
- https://linux-sunxi.org/Manual_build_howto#Build_U-Boot
- https://linux-sunxi.org/Mainline_Kernel_Howto
- https://linux-sunxi.org/Possible_setups_for_hacking_on_mainline
- https://linux-sunxi.org/Device_Tree
