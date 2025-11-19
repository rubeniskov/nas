# BananaPro TFTP boot script for network booting
# Loads kernel, DTB, and optionally rootfs from TFTP server

# TFTP server configuration
# These can be overridden in the U-Boot environment before loading this script
setenv tftp_server_ip ${serverip}
setenv tftp_root_path ${tftproot}

# Default TFTP paths (can be customized)
if test -z "${tftp_kernel}"; then
	setenv tftp_kernel zImage
fi
if test -z "${tftp_dtb}"; then
	setenv tftp_dtb allwinner/sun7i-a20-bananapro.dtb
fi
if test -z "${tftp_overlay}"; then
	setenv tftp_overlay overlays/bpi-m1p-lcd.dtbo
fi

# Network boot configuration
# If ipaddr is not set, attempt DHCP
if test -z "${ipaddr}"; then
	echo "Attempting DHCP configuration..."
	if dhcp; then
		echo "DHCP successful: IP=${ipaddr}, Server=${serverip}"
	else
		echo "ERROR: DHCP failed"
		echo "Please configure network manually:"
		echo "  setenv ipaddr <board_ip>"
		echo "  setenv serverip <tftp_server_ip>"
		echo "  setenv netmask <netmask>"
		echo "  setenv gatewayip <gateway_ip>"
		reset
	fi
fi

# Verify TFTP server is set
if test -z "${serverip}"; then
	echo "ERROR: TFTP server IP not configured"
	echo "Set serverip with: setenv serverip <tftp_server_ip>"
	reset
fi

echo "Network configuration:"
echo "  Board IP: ${ipaddr}"
echo "  TFTP Server: ${serverip}"
echo "  Netmask: ${netmask}"
if test -n "${gatewayip}"; then
	echo "  Gateway: ${gatewayip}"
fi

# Root filesystem configuration
# Three modes supported:
#   1. NFS root (default for TFTP boot)
#   2. Local SD/eMMC root (set use_local_root=1)
#   3. initramfs (set use_initramfs=1)

if test "${use_initramfs}" = "1"; then
	# Mode 3: initramfs root
	echo "Using initramfs for root filesystem"
	if test -z "${tftp_initramfs}"; then
		setenv tftp_initramfs rootfs.cpio.gz
	fi
	setenv rootarg "root=/dev/ram0 rw"
elif test "${use_local_root}" = "1"; then
	# Mode 2: Local SD/eMMC root
	echo "Using local storage for root filesystem"
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
else
	# Mode 1: NFS root (default)
	echo "Using NFS for root filesystem"
	if test -z "${nfsroot}"; then
		setenv nfsroot ${serverip}:/srv/nfs/bananapro,vers=3
	fi
	echo "NFS root: ${nfsroot}"
	setenv rootarg "root=/dev/nfs nfsroot=${nfsroot} ip=${ipaddr}:${serverip}:${gatewayip}:${netmask}::eth0:off"
fi

# Set kernel command line arguments
setenv bootargs console=${console} console=tty1 ${rootarg} rootwait panic=10 ${extra}

# Load device tree from TFTP
echo "Loading DTB from TFTP: ${tftp_dtb}"
if tftp ${fdt_addr_r} ${tftp_dtb}; then
	echo "DTB loaded successfully"
else
	echo "ERROR: Failed to load DTB from TFTP"
	echo "Verify: ${tftp_server_ip}:${tftp_dtb}"
	reset
fi

# Apply device tree overlay if configured
if test -n "${tftp_overlay}" && test "${skip_overlay}" != "1"; then
	if test -z "${overlay_addr_r}"; then
		setenv overlay_addr_r 0x45000000
	fi
	echo "Loading overlay from TFTP: ${tftp_overlay}"
	if tftp ${overlay_addr_r} ${tftp_overlay}; then
		fdt addr ${fdt_addr_r}
		fdt resize 0x10000
		if fdt apply ${overlay_addr_r}; then
			echo "Applied overlay ${tftp_overlay}"
		else
			echo "Warning: failed to apply overlay ${tftp_overlay}"
		fi
	else
		echo "Warning: could not load overlay ${tftp_overlay}"
	fi
fi

# Load initramfs if using initramfs mode
if test "${use_initramfs}" = "1"; then
	if test -z "${ramdisk_addr_r}"; then
		setenv ramdisk_addr_r 0x46000000
	fi
	echo "Loading initramfs from TFTP: ${tftp_initramfs}"
	if tftp ${ramdisk_addr_r} ${tftp_initramfs}; then
		echo "Initramfs loaded successfully"
		setenv initrd_size ${filesize}
	else
		echo "ERROR: Failed to load initramfs from TFTP"
		reset
	fi
fi

# Load kernel from TFTP
echo "Loading kernel from TFTP: ${tftp_kernel}"
if tftp ${kernel_addr_r} ${tftp_kernel}; then
	echo "Kernel loaded successfully"
	# Boot the kernel
	if test "${use_initramfs}" = "1"; then
		bootz ${kernel_addr_r} ${ramdisk_addr_r}:${initrd_size} ${fdt_addr_r}
	else
		bootz ${kernel_addr_r} - ${fdt_addr_r}
	fi
else
	echo "ERROR: Failed to load kernel from TFTP"
	echo "Verify: ${tftp_server_ip}:${tftp_kernel}"
	reset
fi
