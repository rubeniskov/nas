#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF' >&2
Usage: sudo create-arch-rootfs.sh [options] [DEVICE]

Options:
  --image <path>           Build into a loopback image instead of a block device.
  --image-size-mb <int>    Size of the image when --image is used (default: 2048).
  --tgz <path>             After building an image, tar+gzip it for SD distribution.
  --rootfs-url <url>       Override Arch Linux ARM rootfs tarball URL.
  --artifacts-dir <path>   Path to banapro build artifacts (default: artifacts/banapro).
  --board-dtb <file>       Kernel DTB filename to install (default: sun7i-a20-bananapro.dtb).
  --lcd-dtbo <file>        Overlay DTBO filename to install (default: bpi-m1p-lcd.dtbo).
  -h, --help               Show this help.

If DEVICE is supplied (e.g. /dev/sdX), it will be overwritten in-place.
EOF
	exit 1
}

[[ "${EUID}" -eq 0 ]] || { echo "Run as root." >&2; usage; }

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOWNLOAD_DIR="${ROOT_DIR}/downloads"
DEFAULT_ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"
ROOTFS_URL="${ARCH_ROOTFS_URL:-${DEFAULT_ROOTFS_URL}}"
ARTIFACTS_DIR="${BANAPRO_ARTIFACTS_DIR:-${ROOT_DIR}/artifacts/banapro}"
BOARD_DTB="${BOARD_DTB:-sun7i-a20-bananapro.dtb}"
LCD_DTBO="${LCD_DTBO:-bpi-m1p-lcd.dtbo}"
IMAGE_PATH=""
IMAGE_SIZE_MB=${IMAGE_SIZE_MB:-2048}
TGZ_OUTPUT="${TGZ_OUTPUT:-}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--image)
			IMAGE_PATH="$2"
			shift 2
			;;
		--image-size-mb)
			IMAGE_SIZE_MB="$2"
			shift 2
			;;
		--tgz)
			TGZ_OUTPUT="$2"
			shift 2
			;;
		--rootfs-url)
			ROOTFS_URL="$2"
			shift 2
			;;
		--artifacts-dir)
			ARTIFACTS_DIR="$2"
			shift 2
			;;
		--board-dtb)
			BOARD_DTB="$2"
			shift 2
			;;
		--lcd-dtbo)
			LCD_DTBO="$2"
			shift 2
			;;
		-h|--help)
			usage
			;;
		*)
			POSITIONAL+=("$1")
			shift
			;;
	esac
done
set -- "${POSITIONAL[@]:-}"

DEVICE="${1:-}"

if [[ -n "${DEVICE}" && -n "${IMAGE_PATH}" ]]; then
	echo "Choose either a DEVICE or --image, not both." >&2
	usage
fi

if [[ -z "${DEVICE}" && -z "${IMAGE_PATH}" ]]; then
	usage
fi

if [[ -n "${DEVICE}" && ! -b "${DEVICE}" ]]; then
	echo "${DEVICE} is not a block device." >&2
	usage
fi

if [[ -n "${IMAGE_PATH}" ]]; then
	IMAGE_PATH=$(readlink -m "${IMAGE_PATH}")
	mkdir -p "$(dirname "${IMAGE_PATH}")"
	fallocate -l "$((IMAGE_SIZE_MB))M" "${IMAGE_PATH}"
fi

MOUNT_DIR=$(mktemp -d)
LOOP_DEVICE=""
TARGET_BLOCK="${DEVICE}"
APT_PKGS=(wget libarchive-tools u-boot-tools dosfstools util-linux e2fsprogs rsync)

log() { printf '[arch-rootfs] %s\n' "$*" >&2; }

cleanup() {
	if mountpoint -q "${MOUNT_DIR}"; then
		umount "${MOUNT_DIR}" || true
	fi
	rmdir "${MOUNT_DIR}"
	if [[ -n "${LOOP_DEVICE}" ]]; then
		losetup -d "${LOOP_DEVICE}" || true
	fi
}
trap cleanup EXIT

if command -v apt-get >/dev/null 2>&1; then
	log "ensuring host packages: ${APT_PKGS[*]}"
	apt-get update
	apt-get install -y "${APT_PKGS[@]}"
else
	log "apt-get not found; install prerequisites manually."
fi

if [[ -n "${DEVICE}" ]]; then
	read -rp "This will destroy all data on ${DEVICE}. Type 'yes' to continue: " confirm
	[[ "${confirm}" == "yes" ]] || { log "aborted"; exit 1; }

	log "unmounting existing partitions on ${DEVICE}"
	lsblk -lnpo NAME "${DEVICE}" | tail -n +2 | while read -r part; do
		if mountpoint -q "${part}"; then
			umount "${part}"
		fi
	done
else
	log "attaching loop device for ${IMAGE_PATH}"
	LOOP_DEVICE=$(losetup --show -fP "${IMAGE_PATH}")
	TARGET_BLOCK="${LOOP_DEVICE}"
fi

PARTITION_SUFFIX="p1"
if [[ -n "${DEVICE}" ]]; then
	PARTITION_SUFFIX=$([[ "${DEVICE}" =~ [0-9]$ ]] && echo "p1" || echo "1")
fi

PARTITION=$([[ -n "${DEVICE}" ]] && echo "${DEVICE}${PARTITION_SUFFIX}" || echo "${TARGET_BLOCK}${PARTITION_SUFFIX}")

log "zeroing first 8MB of ${TARGET_BLOCK}"
dd if=/dev/zero of="${TARGET_BLOCK}" bs=1M count=8 conv=fsync

log "creating single ext4 partition"
sfdisk "${TARGET_BLOCK}" <<<'label: dos
, , L, *
'
partprobe "${TARGET_BLOCK}" || true

log "creating ext4 filesystem on ${PARTITION}"
mkfs.ext4 -F "${PARTITION}"

log "mounting ${PARTITION} at ${MOUNT_DIR}"
mount "${PARTITION}" "${MOUNT_DIR}"

mkdir -p "${DOWNLOAD_DIR}"

ROOTFS_TAR="${DOWNLOAD_DIR}/$(basename "${ROOTFS_URL}")"
if [[ ! -f "${ROOTFS_TAR}" ]]; then
	log "downloading Arch Linux ARM rootfs"
	wget -O "${ROOTFS_TAR}" "${ROOTFS_URL}"
fi

log "extracting rootfs"
bsdtar -xpf "${ROOTFS_TAR}" -C "${MOUNT_DIR}"

install_kernel_artifacts() {
	local kernel_src="${ARTIFACTS_DIR}/zImage"
	local modules_src="${ARTIFACTS_DIR}/modules/lib/modules"
	local dtb_src="${ARTIFACTS_DIR}/${BOARD_DTB}"
	local dtbo_src="${ARTIFACTS_DIR}/${LCD_DTBO}"
	local boot_dir="${MOUNT_DIR}/boot"

	if [[ ! -f "${kernel_src}" ]]; then
		log "warning: ${kernel_src} not found; skipping custom kernel copy"
		return
	fi

	mkdir -p "${boot_dir}"
	log "installing custom kernel and DTB"
	cp "${kernel_src}" "${boot_dir}/zImage"
	if [[ -f "${dtb_src}" ]]; then
		cp "${dtb_src}" "${boot_dir}/${BOARD_DTB}"
	else
		log "warning: DTB ${dtb_src} missing"
	fi

	if [[ -f "${dtbo_src}" ]]; then
		mkdir -p "${boot_dir}/overlays"
		cp "${dtbo_src}" "${boot_dir}/overlays/${LCD_DTBO}"
	else
		log "warning: overlay ${dtbo_src} missing"
	fi

	if [[ -d "${modules_src}" ]]; then
		log "syncing kernel modules"
		rm -rf "${MOUNT_DIR}/lib/modules"
		mkdir -p "${MOUNT_DIR}/lib"
		cp -a "${modules_src}" "${MOUNT_DIR}/lib/modules"
	else
		log "warning: modules directory ${modules_src} missing"
	fi
}

install_kernel_artifacts

generate_boot_script() {
	local boot_dir="${MOUNT_DIR}/boot"
	local boot_cmd="${boot_dir}/boot.cmd"
	cat >"${boot_cmd}" <<EOF
setenv kernel_addr_r 0x42000000
setenv fdt_addr_r 0x43000000
setenv overlay_addr_r 0x43400000
setenv console ttyS0,115200
setenv rootdev /dev/mmcblk0p1
setenv bootargs "console=\${console} root=\${rootdev} rootwait rw loglevel=4"
ext4load mmc 0:1 \${kernel_addr_r} /boot/zImage
ext4load mmc 0:1 \${fdt_addr_r} /boot/${BOARD_DTB}
EOF

	if [[ -f "${boot_dir}/overlays/${LCD_DTBO}" ]]; then
		cat >>"${boot_cmd}" <<EOF
ext4load mmc 0:1 \${overlay_addr_r} /boot/overlays/${LCD_DTBO}
fdt addr \${fdt_addr_r}
fdt resize
fdt apply \${overlay_addr_r}
EOF
	fi

	cat >>"${boot_cmd}" <<'EOF'
bootz ${kernel_addr_r} - ${fdt_addr_r}
EOF

	mkimage -A arm -T script -C none -n "BananaPro boot" -d "${boot_cmd}" "${boot_dir}/boot.scr"
	rm -f "${boot_cmd}"
}

if command -v mkimage >/dev/null 2>&1; then
	log "generating boot.scr"
	generate_boot_script
else
	log "warning: mkimage not found; skipping boot.scr generation"
fi

install_uboot() {
	local local_uboot="${ARTIFACTS_DIR}/u-boot-sunxi-with-spl.bin"
	local dest_block="${TARGET_BLOCK}"
	if [[ -f "${local_uboot}" ]]; then
		log "writing local U-Boot to ${dest_block}"
		dd if="${local_uboot}" of="${dest_block}" bs=1024 seek=8 conv=fsync
	else
		log "error: ${local_uboot} not found; build artifacts via scripts/banapro-build.sh first"
		exit 1
	fi
}

install_uboot

sync
umount "${MOUNT_DIR}"

if [[ -n "${LOOP_DEVICE}" ]]; then
	losetup -d "${LOOP_DEVICE}"
	LOOP_DEVICE=""
	log "image created at ${IMAGE_PATH}"
	if [[ -n "${TGZ_OUTPUT}" ]]; then
		mkdir -p "$(dirname "${TGZ_OUTPUT}")"
		log "packing ${IMAGE_PATH} into ${TGZ_OUTPUT}"
		tar -C "$(dirname "${IMAGE_PATH}")" -czf "${TGZ_OUTPUT}" "$(basename "${IMAGE_PATH}")"
	fi
else
	log "rootfs ready on ${DEVICE}. Insert into the board, boot, then run pacman-key --init && pacman-key --populate archlinuxarm."
fi
