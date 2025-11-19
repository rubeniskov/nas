# BananaPro boot script with LCD overlay and PARTUUID rootfs

setenv boot_iface mmc
setenv bootpart 1
setenv devnum 0

if itest.b *0x28 == 0x02 ; then
	echo "U-Boot loaded from eMMC or secondary SD"
	setenv devnum 1
fi

if part uuid ${boot_iface} ${devnum}:2 rootuuid; then
	echo "Root filesystem PARTUUID=${rootuuid}"
	setenv rootarg "root=PARTUUID=${rootuuid}"
else
	echo "Warning: unable to determine PARTUUID, falling back to /dev/mmcblk${devnum}p2"
	setenv rootarg "root=/dev/mmcblk${devnum}p2"
fi

setenv bootargs console=${console} console=tty1 ${rootarg} rootwait panic=10 ${extra}

if load ${boot_iface} ${devnum}:${bootpart} ${fdt_addr_r} ${fdtfile}; then
	true
elif load ${boot_iface} ${devnum}:${bootpart} ${fdt_addr_r} boot/allwinner/${fdtfile}; then
	echo "Loaded FDT from boot/allwinner"
else
	echo "ERROR: Unable to load FDT ${fdtfile}"
	reset
fi

if test -z "${overlay_addr_r}"; then
	setenv overlay_addr_r 0x45000000
fi
setenv overlay_file overlays/bpi-m1p-lcd.dtbo
if load ${boot_iface} ${devnum}:${bootpart} ${overlay_addr_r} ${overlay_file}; then
	fdt addr ${fdt_addr_r}
	fdt resize 0x10000
	if fdt apply ${overlay_addr_r}; then
		echo "Applied overlay ${overlay_file}"
	else
		echo "Warning: failed to apply overlay ${overlay_file}"
	fi
else
	echo "Warning: could not load overlay ${overlay_file}"
fi

if load ${boot_iface} ${devnum}:${bootpart} ${kernel_addr_r} zImage; then
	bootz ${kernel_addr_r} - ${fdt_addr_r}
elif load ${boot_iface} ${devnum}:${bootpart} ${kernel_addr_r} boot/zImage; then
	echo "Loaded kernel from boot/zImage"
	bootz ${kernel_addr_r} - ${fdt_addr_r}
elif load ${boot_iface} ${devnum}:${bootpart} ${kernel_addr_r} uImage; then
	bootm ${kernel_addr_r} - ${fdt_addr_r}
elif load ${boot_iface} ${devnum}:${bootpart} ${kernel_addr_r} boot/uImage; then
	echo "Loaded kernel from boot/uImage"
	bootm ${kernel_addr_r} - ${fdt_addr_r}
else
	echo "ERROR: Unable to load kernel image"
	reset
fi
