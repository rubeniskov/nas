# TFTP Boot Quick Reference

## Quick Start

### 1. Set up TFTP server
```bash
sudo apt-get install tftpd-hpa
sudo mkdir -p /srv/tftp/allwinner
sudo cp zImage /srv/tftp/
sudo cp sun7i-a20-bananapro.dtb /srv/tftp/allwinner/
```

### 2. Configure U-Boot
At U-Boot prompt:
```
setenv serverip 192.168.1.100
setenv ipaddr 192.168.1.200
load mmc 0:1 ${scriptaddr} boot-tftp.scr
source ${scriptaddr}
```

## Three Boot Modes

### NFS Root (Development)
```
# Default - kernel, DTB, and rootfs from network
```

### Local Root (Kernel Testing)
```
setenv use_local_root 1
# Kernel/DTB from TFTP, rootfs from SD/eMMC
```

### Initramfs (Recovery)
```
setenv use_initramfs 1
setenv tftp_initramfs rootfs.cpio.gz
# Complete system from TFTP
```

## Files Created

- `boot-banapro-tftp.cmd` - TFTP boot script source
- `boot-tftp.scr` - Compiled boot script (in boot partition)
- `tftp.cfg` - U-Boot network configuration fragment
- `docs/TFTP_BOOT_CONFIGURATION.md` - Full documentation

## See Also

- Full documentation: [docs/TFTP_BOOT_CONFIGURATION.md](TFTP_BOOT_CONFIGURATION.md)
- Repository README: [README.md](../README.md)
- Meta layer README: [meta-banapro/README.md](../meta-banapro/README.md)
