#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

usage() {
	cat <<'EOF' >&2
Usage: sudo image.sh --rootfs-tar <path> [options]

Options:
  --rootfs-tar <path>     Path to a prebuilt Arch Linux ARM rootfs tarball (required).
  --image <path>          Output disk image path (default: artifacts/banapro/archlinuxarm-bananapro.img).
  --image-size-mb <int>   Size of the sparse image in MiB (default: 2048).
  --tgz <path>            Additionally create a .tgz containing the image.
  --board-dtb <file>      Override DTB filename to install (default env BOARD_DTB).
  --lcd-dtbo <file>       Override LCD overlay filename (default env LCD_DTBO).
  -h, --help              Show this help.
EOF
	exit 1
}

[[ "${EUID}" -eq 0 ]] || { echo "Run as root." >&2; usage; }

ROOTFS_TAR=""
IMAGE_PATH=""
IMAGE_SIZE_MB=${IMAGE_SIZE_MB:-2048}
TGZ_OUTPUT=""
BOARD_DTB_OVERRIDE=""
LCD_DTBO_OVERRIDE=""

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--rootfs-tar)
			ROOTFS_TAR="$2"
			shift 2
			;;
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
		--board-dtb)
			BOARD_DTB_OVERRIDE="$2"
			shift 2
			;;
		--lcd-dtbo)
			LCD_DTBO_OVERRIDE="$2"
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

[[ ${#POSITIONAL[@]} -eq 0 ]] || usage

[[ -n "${ROOTFS_TAR}" ]] || { echo "--rootfs-tar is required." >&2; usage; }

ROOTFS_TAR=$(readlink -m "${ROOTFS_TAR}")
[[ -f "${ROOTFS_TAR}" ]] || { echo "rootfs tar ${ROOTFS_TAR} not found" >&2; exit 1; }

if [[ -z "${IMAGE_PATH}" ]]; then
	IMAGE_PATH="${ARTIFACTS_DIR}/archlinuxarm-bananapro.img"
fi
IMAGE_PATH=$(readlink -m "${IMAGE_PATH}")
IMAGE_DIR=$(dirname "${IMAGE_PATH}")
mkdir -p "${IMAGE_DIR}"

if [[ -n "${TGZ_OUTPUT}" ]]; then
	TGZ_OUTPUT=$(readlink -m "${TGZ_OUTPUT}")
	mkdir -p "$(dirname "${TGZ_OUTPUT}")"
fi

[[ "${IMAGE_SIZE_MB}" =~ ^[0-9]+$ ]] || { echo "--image-size-mb must be numeric" >&2; exit 1; }

if [[ -n "${BOARD_DTB_OVERRIDE}" ]]; then
	BOARD_DTB="${BOARD_DTB_OVERRIDE}"
fi
if [[ -n "${LCD_DTBO_OVERRIDE}" ]]; then
	LCD_DTBO="${LCD_DTBO_OVERRIDE}"
fi

ensure_packages

MOUNT_DIR=$(mktemp -d)
LOOP_DEVICE=""
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

log "creating sparse image ${IMAGE_PATH} (${IMAGE_SIZE_MB} MiB)"
truncate -s 0 "${IMAGE_PATH}"
fallocate -l "$((IMAGE_SIZE_MB))M" "${IMAGE_PATH}"

LOOP_DEVICE=$(losetup --show -fP "${IMAGE_PATH}")
PARTITION="${LOOP_DEVICE}p1"

log "partitioning ${LOOP_DEVICE}"
sfdisk "${LOOP_DEVICE}" <<<'label: dos
, , L, *
'
partprobe "${LOOP_DEVICE}" || true

log "creating ext4 filesystem"
mkfs.ext4 -F "${PARTITION}"

log "mounting rootfs"
mount "${PARTITION}" "${MOUNT_DIR}"

log "extracting rootfs from ${ROOTFS_TAR}"
bsdtar -xpf "${ROOTFS_TAR}" -C "${MOUNT_DIR}"

install_kernel_artifacts() {
	local kernel_src="${ARTIFACTS_DIR}/zImage"
	local modules_src="${ARTIFACTS_DIR}/modules/lib/modules"
	local dtb_src="${ARTIFACTS_DIR}/${BOARD_DTB}"
	local dtbo_src="${ARTIFACTS_DIR}/${LCD_DTBO}"
	local boot_dir="${MOUNT_DIR}/boot"

	[[ -f "${kernel_src}" ]] || { log "error: kernel image ${kernel_src} missing"; exit 1; }
	mkdir -p "${boot_dir}"
	log "copying kernel image"
	cp "${kernel_src}" "${boot_dir}/zImage"

	if [[ -f "${dtb_src}" ]]; then
		cp "${dtb_src}" "${boot_dir}/${BOARD_DTB}"
	else
		log "error: DTB ${dtb_src} missing"
		exit 1
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
setenv fdt_size 0x00100000
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
	fdt addr \${fdt_addr_r} \${fdt_size}
	fdt resize 0x20000
fdt apply \${overlay_addr_r}
EOF
	fi

	cat >>"${boot_cmd}" <<'EOF'
bootz ${kernel_addr_r} - ${fdt_addr_r}
EOF

	if command -v mkimage >/dev/null 2>&1; then
		mkimage -A arm -T script -C none -n "BananaPro boot" -d "${boot_cmd}" "${boot_dir}/boot.scr"
		rm -f "${boot_cmd}"
	else
		log "warning: mkimage not found; leaving boot.cmd"
	fi
}

log "generating boot script"
generate_boot_script

install_uboot() {
	local local_uboot="${ARTIFACTS_DIR}/u-boot-sunxi-with-spl.bin"
	[[ -f "${local_uboot}" ]] || { log "error: ${local_uboot} missing. Run banapro.sh build first."; exit 1; }
	log "writing U-Boot to ${LOOP_DEVICE}"
	dd if="${local_uboot}" of="${LOOP_DEVICE}" bs=1024 seek=8 conv=fsync
}

install_uboot

sync
umount "${MOUNT_DIR}"
losetup -d "${LOOP_DEVICE}"
LOOP_DEVICE=""

if [[ -n "${TGZ_OUTPUT}" ]]; then
	log "archiving image to ${TGZ_OUTPUT}"
	tar -C "${IMAGE_DIR}" -czf "${TGZ_OUTPUT}" "$(basename "${IMAGE_PATH}")"
fi

log "image ready at ${IMAGE_PATH}"
exit 0
