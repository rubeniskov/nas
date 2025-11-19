# TFTP Boot Configuration for U-Boot

This guide explains how to configure U-Boot on the BananaPro to load the kernel, device tree blobs (DTBs), and root filesystem from a TFTP server over the network.

> **Quick Start**: For a condensed reference, see [TFTP_BOOT_QUICK_REFERENCE.md](TFTP_BOOT_QUICK_REFERENCE.md)

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [TFTP Server Setup](#tftp-server-setup)
- [U-Boot Configuration](#u-boot-configuration)
- [Boot Modes](#boot-modes)
- [Network Configuration](#network-configuration)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Overview

Network booting via TFTP is useful for:
- **Development**: Rapidly test kernel and rootfs changes without reflashing SD cards
- **Diskless systems**: Boot multiple boards from a central server
- **Recovery**: Access systems with corrupted local storage
- **Automated testing**: Deploy test images programmatically

The BananaPro U-Boot TFTP configuration supports three root filesystem modes:
1. **NFS root** (recommended): Mount root filesystem via NFS
2. **Local storage**: Load kernel/DTB from TFTP but use local SD/eMMC for rootfs
3. **Initramfs**: Load a complete root filesystem image into RAM

## Prerequisites

### Hardware Requirements
- BananaPro board with working Ethernet connection
- Network switch/router with DHCP (or static IP configuration)
- Linux server for TFTP and optionally NFS

### Software Requirements
- TFTP server (tftpd-hpa, atftpd, or dnsmasq)
- NFS server (optional, for NFS root mode)
- Compiled kernel image (zImage)
- Device tree blob (sun7i-a20-bananapro.dtb)
- Optional: Device tree overlay (bpi-m1p-lcd.dtbo)
- Optional: Root filesystem (for NFS or initramfs)

## TFTP Server Setup

### Installing TFTP Server (Ubuntu/Debian)

```bash
# Install TFTP server
sudo apt-get update
sudo apt-get install tftpd-hpa

# Configure TFTP server
sudo systemctl stop tftpd-hpa
sudo mkdir -p /srv/tftp
sudo chown tftp:tftp /srv/tftp
sudo chmod 755 /srv/tftp

# Edit /etc/default/tftpd-hpa
sudo tee /etc/default/tftpd-hpa <<EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --verbose"
EOF

# Start TFTP server
sudo systemctl start tftpd-hpa
sudo systemctl enable tftpd-hpa
```

### Setting Up Boot Files

```bash
# Create directory structure
sudo mkdir -p /srv/tftp/{allwinner,overlays}

# Copy kernel image
sudo cp /path/to/zImage /srv/tftp/

# Copy device tree
sudo cp /path/to/sun7i-a20-bananapro.dtb /srv/tftp/allwinner/

# Copy overlay (optional, for LCD support)
sudo cp /path/to/bpi-m1p-lcd.dtbo /srv/tftp/overlays/

# Set permissions
sudo chmod -R 755 /srv/tftp
```

### Yocto/Bitbake Build Artifacts

If using the Yocto build in this repository:

```bash
# Assuming you've built the banapro-image
DEPLOY_DIR="path/to/yocto/build/tmp/deploy/images/bananapro"

# Copy kernel
sudo cp ${DEPLOY_DIR}/zImage /srv/tftp/

# Copy DTB
sudo cp ${DEPLOY_DIR}/sun7i-a20-bananapro.dtb /srv/tftp/allwinner/

# Copy overlay
sudo cp ${DEPLOY_DIR}/bpi-m1p-lcd.dtbo /srv/tftp/overlays/
```

## U-Boot Configuration

### Building U-Boot with TFTP Support

The U-Boot configuration in `meta-banapro/recipes-bsp/u-boot/u-boot-banapro/tftp.cfg` enables all necessary network and TFTP features. These are automatically included when building via Yocto:

```bash
# Build U-Boot with TFTP support using Yocto
./scripts/yocto_build.sh
```

Or build manually:
```bash
make -C u-boot-source Bananapro_defconfig
./scripts/kconfig/merge_config.sh -m .config tftp.cfg
make -C u-boot-source -j$(nproc)
```

### Boot Script Selection

The repository includes two boot scripts:

1. **boot-banapro.cmd**: Default SD/eMMC boot (current default)
2. **boot-banapro-tftp.cmd**: Network/TFTP boot (new)

To enable TFTP boot, you can either:

#### Option A: Make TFTP boot script the default

Edit `meta-banapro/recipes-bsp/u-boot/u-boot_%.bbappend`:

```diff
 do_compile:prepend:bananapro() {
     # ...
-    install -m 0644 ${WORKDIR}/boot-banapro.cmd ${WORKDIR}/boot.cmd
+    install -m 0644 ${WORKDIR}/boot-banapro-tftp.cmd ${WORKDIR}/boot.cmd
 }
```

#### Option B: Load TFTP boot script manually from U-Boot

Keep both scripts and load the TFTP one when needed:

```
# At U-Boot prompt
load mmc 0:1 ${scriptaddr} boot-tftp.scr
source ${scriptaddr}
```

## Boot Modes

### Mode 1: NFS Root (Default for TFTP)

**Best for development** - Kernel, DTB, and rootfs all from network.

**Server setup:**
```bash
# Install NFS server
sudo apt-get install nfs-kernel-server

# Create NFS export directory
sudo mkdir -p /srv/nfs/bananapro

# Extract rootfs (example with Yocto/Arch rootfs)
sudo tar -xzf banapro-image-*.rootfs.tar.gz -C /srv/nfs/bananapro

# Configure NFS exports - /etc/exports
echo "/srv/nfs/bananapro *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports

# Apply exports
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
```

**U-Boot environment:**
```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv nfsroot 192.168.1.100:/srv/nfs/bananapro,vers=3
# Boot script will use NFS root automatically
```

### Mode 2: Local Root with TFTP Kernel

**Best for testing kernels** - Load kernel/DTB from TFTP but use local rootfs.

**U-Boot environment:**
```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv use_local_root 1
# Boot script will mount SD/eMMC rootfs
```

### Mode 3: Initramfs

**Best for recovery** - Complete system loaded into RAM.

**Server setup:**
```bash
# Create initramfs (example)
cd /srv/tftp
sudo mkinitcpio -c /etc/mkinitcpio.conf -g rootfs.cpio.gz
# Or use a pre-built initramfs from your build system
```

**U-Boot environment:**
```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv use_initramfs 1
setenv tftp_initramfs rootfs.cpio.gz
```

## Network Configuration

### DHCP (Automatic)

The boot script attempts DHCP by default:

```
# No manual configuration needed
# Boot script will run: dhcp
```

### Static IP

Set these variables in U-Boot environment or before running boot script:

```
setenv ipaddr 192.168.1.200
setenv serverip 192.168.1.100
setenv netmask 255.255.255.0
setenv gatewayip 192.168.1.1
saveenv
```

### Persistent Configuration

Save network configuration permanently:

```
# At U-Boot prompt
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv netmask 255.255.255.0
setenv gatewayip 192.168.1.1
setenv ethaddr aa:bb:cc:dd:ee:ff  # Set MAC address if needed
saveenv
```

### Custom File Paths

Override default TFTP paths:

```
setenv tftp_kernel zImage-custom
setenv tftp_dtb allwinner/sun7i-a20-bananapro-custom.dtb
setenv tftp_overlay overlays/custom-lcd.dtbo
# Or disable overlay:
setenv skip_overlay 1
```

## Troubleshooting

### Network Issues

**Problem**: "DHCP failed"
```
# Solution 1: Check physical connection
# Solution 2: Use static IP
setenv ipaddr 192.168.1.200
setenv serverip 192.168.1.100
setenv netmask 255.255.255.0

# Solution 3: Reset network interface
mii device
mii info
```

**Problem**: Cannot reach TFTP server
```
# Test connectivity
ping ${serverip}

# Check TFTP server is running
# On server: sudo systemctl status tftpd-hpa

# Check firewall on server
# On server: sudo ufw allow 69/udp
```

### TFTP Loading Issues

**Problem**: "Failed to load kernel from TFTP"
```
# Verify file exists on server
# On server: ls -la /srv/tftp/zImage

# Check TFTP server logs
# On server: sudo journalctl -u tftpd-hpa -f

# Try loading manually
tftp ${kernel_addr_r} zImage
printenv filesize  # Should show non-zero size
```

**Problem**: "Failed to load DTB from TFTP"
```
# Check DTB path
setenv tftp_dtb allwinner/sun7i-a20-bananapro.dtb
# Or try flat path
setenv tftp_dtb sun7i-a20-bananapro.dtb
```

### NFS Mount Issues

**Problem**: Kernel boots but NFS mount fails
```
# Check NFS exports on server
# On server: sudo exportfs -v

# Check NFS service
# On server: sudo systemctl status nfs-kernel-server

# Verify kernel has NFS support
# Root should have: CONFIG_NFS_FS=y, CONFIG_ROOT_NFS=y

# Try NFSv3 explicitly
setenv nfsroot ${serverip}:/srv/nfs/bananapro,vers=3,tcp
```

### Boot Script Debugging

Enable verbose output in U-Boot:
```
setenv bootargs ${bootargs} debug earlyprintk
```

View boot script execution:
```
# Load and print the script
load mmc 0:1 ${scriptaddr} boot-tftp.scr
# Examine script contents (decoded)
# Or review the source .cmd file
```

## Examples

### Example 1: Quick Development Setup

Server (192.168.1.100):
```bash
# Setup TFTP
sudo apt-get install tftpd-hpa
sudo mkdir -p /srv/tftp/allwinner
sudo cp zImage /srv/tftp/
sudo cp sun7i-a20-bananapro.dtb /srv/tftp/allwinner/

# Setup NFS
sudo apt-get install nfs-kernel-server
sudo mkdir -p /srv/nfs/bananapro
sudo tar -xf rootfs.tar.gz -C /srv/nfs/bananapro
echo "/srv/nfs/bananapro *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra
```

BananaPro U-Boot:
```
# If using DHCP
dhcp
# Or set static IP
setenv ipaddr 192.168.1.200
setenv serverip 192.168.1.100

# Load and run TFTP boot script
load mmc 0:1 ${scriptaddr} boot-tftp.scr
source ${scriptaddr}
```

### Example 2: Testing Kernel Only

Server:
```bash
sudo cp new-zImage /srv/tftp/zImage
```

BananaPro U-Boot:
```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv use_local_root 1
saveenv

# Load and run TFTP boot script
load mmc 0:1 ${scriptaddr} boot-tftp.scr
source ${scriptaddr}
```

### Example 3: Automated TFTP Boot

Make TFTP boot the default by setting environment variables:

```
# At U-Boot prompt
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
setenv bootcmd_tftp 'load mmc 0:1 ${scriptaddr} boot-tftp.scr; source ${scriptaddr}'
setenv bootcmd 'run bootcmd_tftp || run bootcmd_mmc'
saveenv
reset
```

Now the board will attempt TFTP boot first, then fall back to SD/eMMC.

### Example 4: Multiple Boards from One Server

Serve different rootfs per board using NFS exports:

Server `/etc/exports`:
```
/srv/nfs/board1 192.168.1.201(rw,sync,no_root_squash,no_subtree_check)
/srv/nfs/board2 192.168.1.202(rw,sync,no_root_squash,no_subtree_check)
```

Board 1 U-Boot:
```
setenv ipaddr 192.168.1.201
setenv serverip 192.168.1.100
setenv nfsroot 192.168.1.100:/srv/nfs/board1,vers=3
saveenv
```

Board 2 U-Boot:
```
setenv ipaddr 192.168.1.202
setenv serverip 192.168.1.100
setenv nfsroot 192.168.1.100:/srv/nfs/board2,vers=3
saveenv
```

## Advanced Configuration

### Custom Boot Arguments

Add custom kernel command-line arguments:

```
setenv extra "loglevel=7 rootwait rw"
```

### Selective Overlay Loading

Skip LCD overlay if not needed:
```
setenv skip_overlay 1
```

Load different overlay:
```
setenv tftp_overlay overlays/my-custom-overlay.dtbo
```

### Fallback Strategy

Create a boot command that tries TFTP first, then falls back to SD/eMMC:

```
setenv bootcmd_tftp 'if dhcp; then load mmc 0:1 ${scriptaddr} boot-tftp.scr && source ${scriptaddr}; fi'
setenv bootcmd_mmc 'load mmc 0:1 ${scriptaddr} boot.scr && source ${scriptaddr}'
setenv bootcmd 'run bootcmd_tftp || run bootcmd_mmc'
saveenv
```

## Integration with Yocto Build

To include the TFTP boot script in your Yocto build:

1. The `boot-banapro-tftp.cmd` and `tftp.cfg` are already in the repository
2. Edit `meta-banapro/recipes-bsp/u-boot/u-boot_%.bbappend` to include them:

```bitbake
SRC_URI:append:bananapro = " \
    file://lcd.cfg \
    file://tftp.cfg \
    file://boot-banapro.cmd \
    file://boot-banapro-tftp.cmd \
"
```

3. The TFTP script will be built as `boot-tftp.scr` alongside `boot.scr`
4. Both scripts will be available in the boot partition

## References

- [U-Boot TFTP Documentation](https://u-boot.readthedocs.io/en/latest/usage/cmd/tftp.html)
- [Linux NFS Root Documentation](https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt)
- [U-Boot Network Boot](https://u-boot.readthedocs.io/en/latest/develop/bootstd.html)
- [Sunxi U-Boot](https://linux-sunxi.org/U-Boot)
