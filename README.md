You can automate the full Banana Pi M1+ Arch Linux build with:
```
./scripts/bpi-m1p-setup.sh
```

Automation helpers:
- `./scripts/banapro-build.sh` builds the mainline Banana Pro kernel (zImage, dtbs, modules, headers) and U-Boot as described in the Mainline Kernel Howto and U-Boot guide.
- `sudo ./scripts/create-arch-rootfs.sh /dev/sdX` provisions an Arch Linux ARM rootfs on the specified card/drive, mirroring the Arch install steps (set `ARCH_ROOTFS_URL`, `UBOOT_BIN_URL`, or `BOOTSCR_URL` to override defaults).

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
