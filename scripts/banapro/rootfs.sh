#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

usage() {
	cat <<'EOF' >&2
Usage: sudo rootfs.sh [options]

Options:
  --rootfs-url <url>     Source Arch Linux ARM rootfs tarball URL.
  --output <path>        Output tarball path (default: artifacts/banapro/rootfs/banapro-rootfs.tar.gz).
  --work-dir <path>      Working directory (default: temporary directory).
  --downloads <path>     Directory for cached downloads (default: downloads/).
  --board-dtb <file>     Override DTB filename (default env BOARD_DTB).
  --lcd-dtbo <file>      Override overlay filename (default env LCD_DTBO).
  -h, --help             Show this help.
EOF
	exit 1
}

[[ "${EUID}" -eq 0 ]] || { echo "rootfs.sh must run as root" >&2; usage; }

DEFAULT_ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"
ROOTFS_URL="${ARCH_ROOTFS_URL:-${DEFAULT_ROOTFS_URL}}"
OUTPUT_PATH=""
WORK_DIR=""
DOWNLOAD_DIR="${ROOT_DIR}/downloads"
BOARD_DTB_OVERRIDE=""
LCD_DTBO_OVERRIDE=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--rootfs-url)
			ROOTFS_URL="$2"
			shift 2
			;;
		--output)
			OUTPUT_PATH="$2"
			shift 2
			;;
		--work-dir)
			WORK_DIR="$2"
			shift 2
			;;
		--downloads)
			DOWNLOAD_DIR="$2"
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
			echo "unknown option: $1" >&2
			usage
			;;
	esac
 done

if [[ -z "${OUTPUT_PATH}" ]]; then
	OUTPUT_PATH="${ARTIFACTS_DIR}/rootfs/banapro-rootfs.tar.gz"
fi
OUTPUT_PATH=$(readlink -m "${OUTPUT_PATH}")
mkdir -p "$(dirname "${OUTPUT_PATH}")"

if [[ -n "${BOARD_DTB_OVERRIDE}" ]]; then
	BOARD_DTB="${BOARD_DTB_OVERRIDE}"
fi
if [[ -n "${LCD_DTBO_OVERRIDE}" ]]; then
	LCD_DTBO="${LCD_DTBO_OVERRIDE}"
fi

ensure_packages
mkdir -p "${DOWNLOAD_DIR}" "${ARTIFACTS_DIR}"

WORK_DIR_CUSTOM=0
if [[ -z "${WORK_DIR}" ]]; then
	WORK_DIR=$(mktemp -d)
else
	WORK_DIR_CUSTOM=1
	WORK_DIR=$(readlink -m "${WORK_DIR}")
	mkdir -p "${WORK_DIR}"
fi
ROOTFS_DIR="${WORK_DIR}/rootfs"
rm -rf "${ROOTFS_DIR}"
mkdir -p "${ROOTFS_DIR}"

cleanup() {
	rm -rf "${ROOTFS_DIR}"
	if [[ ${WORK_DIR_CUSTOM} -eq 0 ]]; then
		rm -rf "${WORK_DIR}"
	fi
}
trap cleanup EXIT

BASE_TAR="${DOWNLOAD_DIR}/$(basename "${ROOTFS_URL}")"
if [[ ! -f "${BASE_TAR}" ]]; then
	log "downloading base rootfs from ${ROOTFS_URL}"
	wget -O "${BASE_TAR}" "${ROOTFS_URL}"
fi

log "extracting base rootfs"
bsdtar -xpf "${BASE_TAR}" -C "${ROOTFS_DIR}"

install_kernel_artifacts() {
	local kernel_src="${ARTIFACTS_DIR}/zImage"
	local modules_src="${ARTIFACTS_DIR}/modules/lib/modules"
	local dtb_src="${ARTIFACTS_DIR}/${BOARD_DTB}"
	local dtbo_src="${ARTIFACTS_DIR}/${LCD_DTBO}"
	local boot_dir="${ROOTFS_DIR}/boot"

	[[ -f "${kernel_src}" ]] || { log "error: kernel image ${kernel_src} missing"; exit 1; }
	mkdir -p "${boot_dir}"
	cp "${kernel_src}" "${boot_dir}/zImage"

	if [[ -f "${dtb_src}" ]]; then
		cp "${dtb_src}" "${boot_dir}/${BOARD_DTB}"
	else
		log "error: DTB ${dtb_src} missing"; exit 1
	fi

	if [[ -f "${dtbo_src}" ]]; then
		mkdir -p "${boot_dir}/overlays"
		cp "${dtbo_src}" "${boot_dir}/overlays/${LCD_DTBO}"
	else
		log "warning: overlay ${dtbo_src} missing"
	fi

	if [[ -d "${modules_src}" ]]; then
		log "syncing kernel modules"
		rm -rf "${ROOTFS_DIR}/lib/modules"
		mkdir -p "${ROOTFS_DIR}/lib"
		cp -a "${modules_src}" "${ROOTFS_DIR}/lib/modules"
	else
		log "warning: modules directory ${modules_src} missing"
	fi
}

install_kernel_artifacts

log "packaging rootfs to ${OUTPUT_PATH}"
bsdtar -cpf - -C "${ROOTFS_DIR}" . | gzip -c > "${OUTPUT_PATH}"
log "rootfs tarball ready at ${OUTPUT_PATH}"
