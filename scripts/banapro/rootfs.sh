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
EXTRA_PACKAGES=(
	vim
	cloud-guest-utils
	sudo
	mesa
	mesa-demos
	mesa-utils
	weston
	seatd
	wayland-utils
	glmark2
)
QEMU_STATIC_BIN="/usr/bin/qemu-arm-static"
HOST_RESOLV_CONF="${HOST_RESOLV_CONF:-/etc/resolv.conf}"
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
CHROOT_MOUNTS_ACTIVE=0
RESOLV_CONF_BACKUP=""
RESOLV_CONF_RESTORE_MODE=""
CHROOT_MOUNTS_ACTIVE=0
RESOLV_CONF_BACKUP=""
RESOLV_CONF_RESTORE_MODE=""

cleanup() {
	if [[ ${CHROOT_MOUNTS_ACTIVE} -eq 1 ]]; then
		umount_chroot_fs || true
	fi
	if [[ ${CHROOT_MOUNTS_ACTIVE} -eq 1 ]]; then
		umount_chroot_fs || true
	fi
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

sync_resolv_conf() {
	if [[ -f "${HOST_RESOLV_CONF}" ]]; then
		log "copying host resolv.conf for chroot networking"
		rm -f "${ROOTFS_DIR}/etc/resolv.conf"
		install -m 0644 "${HOST_RESOLV_CONF}" "${ROOTFS_DIR}/etc/resolv.conf"
	else
		log "warning: host resolv.conf ${HOST_RESOLV_CONF} not found; DNS may fail inside chroot"
	fi
}

sync_resolv_conf

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

mount_chroot_fs() {
	mount -t proc proc "${ROOTFS_DIR}/proc"
	mount --rbind /sys "${ROOTFS_DIR}/sys"
	mount --make-rslave "${ROOTFS_DIR}/sys"
	mount --rbind /dev "${ROOTFS_DIR}/dev"
	mount --make-rslave "${ROOTFS_DIR}/dev"
	mount --rbind /run "${ROOTFS_DIR}/run"
	mount --make-rslave "${ROOTFS_DIR}/run"
	CHROOT_MOUNTS_ACTIVE=1
}

umount_chroot_fs() {
	local target
	for target in run dev sys proc; do
		if mountpoint -q "${ROOTFS_DIR}/${target}"; then
			umount -R "${ROOTFS_DIR}/${target}" || umount -Rl "${ROOTFS_DIR}/${target}" || true
		fi
	done
	CHROOT_MOUNTS_ACTIVE=0
}

ensure_qemu_static() {
	if [[ ! -x "${QEMU_STATIC_BIN}" ]]; then
		log "error: ${QEMU_STATIC_BIN} not found; install qemu-user-static on the host"
		exit 1
	fi
	mkdir -p "${ROOTFS_DIR}/usr/bin"
	cp "${QEMU_STATIC_BIN}" "${ROOTFS_DIR}${QEMU_STATIC_BIN}"
}

remove_qemu_static() {
	rm -f "${ROOTFS_DIR}${QEMU_STATIC_BIN}"
}

configure_pacman_sandbox() {
	local pacman_conf="${ROOTFS_DIR}/etc/pacman.conf"
	[[ -f "${pacman_conf}" ]] || { log "error: missing ${pacman_conf}"; exit 1; }
	if ! grep -Eq '^[[:space:]]*DisableSandbox([[:space:]]|$)' "${pacman_conf}"; then
		awk 'BEGIN{inserted=0} {print; if (!inserted && $0 ~ /^\[options\]/) {print "DisableSandbox"; inserted=1}}' "${pacman_conf}" > "${pacman_conf}.tmp"
		mv "${pacman_conf}.tmp" "${pacman_conf}"
	fi
	if grep -Eq '^[[:space:]]*CheckSpace([[:space:]]|$)' "${pacman_conf}"; then
		log "disabling pacman CheckSpace to avoid cachedir mount checks"
		awk 'BEGIN{done=0} {
			if (!done && $0 ~ /^[[:space:]]*CheckSpace(\b|$)/) {
				print "#" $0 " (disabled for chroot build)"
				done=1
			} else {
				print
			}
		}' "${pacman_conf}" > "${pacman_conf}.tmp"
		mv "${pacman_conf}.tmp" "${pacman_conf}"
	fi
}

setup_chroot_resolv_conf() {
	local target="${ROOTFS_DIR}/etc/resolv.conf"
	RESOLV_CONF_BACKUP=""
	RESOLV_CONF_RESTORE_MODE=""
	if [[ -e "${target}" || -L "${target}" ]]; then
		RESOLV_CONF_BACKUP="${ROOTFS_DIR}/etc/.resolv.conf.nasbak"
		rm -f "${RESOLV_CONF_BACKUP}"
		cp -a "${target}" "${RESOLV_CONF_BACKUP}"
		RESOLV_CONF_RESTORE_MODE="restore"
	else
		RESOLV_CONF_RESTORE_MODE="delete"
	fi
	if [[ -f /etc/resolv.conf ]]; then
		cp -L /etc/resolv.conf "${target}"
	else
		touch "${target}"
	fi
}

restore_chroot_resolv_conf() {
	local target="${ROOTFS_DIR}/etc/resolv.conf"
	case "${RESOLV_CONF_RESTORE_MODE}" in
		restore)
			if [[ -n "${RESOLV_CONF_BACKUP}" && -e "${RESOLV_CONF_BACKUP}" ]]; then
				mv -Tf "${RESOLV_CONF_BACKUP}" "${target}"
			fi
			;;
		delete)
			rm -f "${target}"
			;;
	esac
	RESOLV_CONF_BACKUP=""
	RESOLV_CONF_RESTORE_MODE=""
}

write_rootfs_size_metadata() {
	local size_bytes size_mib meta_path
	size_bytes=$(du -sb "${ROOTFS_DIR}" | awk '{print $1}')
	meta_path="${OUTPUT_PATH}.size"
	printf '%s\n' "${size_bytes}" > "${meta_path}"
	chmod 0644 "${meta_path}"
	size_mib=$(( (size_bytes + 1048575) / 1048576 ))
	log "rootfs size ~${size_mib} MiB recorded at ${meta_path}"
}

customize_rootfs() {
	log "customizing rootfs packages and services"
	configure_pacman_sandbox
	setup_chroot_resolv_conf
	ensure_qemu_static
	mount_chroot_fs
	local pkg_list
	printf -v pkg_list '%q ' "${EXTRA_PACKAGES[@]}"
	set +e
	chroot "${ROOTFS_DIR}" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin LANG=C LC_ALL=C /bin/bash -eu <<CHROOT
set -euo pipefail
	export PACMAN_DISABLE_SANDBOX=1
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
pacman -S --needed --noconfirm ${pkg_list}
groupadd -f render
groupadd -f seat
usermod -aG video,render,seat alarm
install -m 0640 -D /dev/null /etc/sudoers.d/90-alarm
cat <<'SUDOERS' > /etc/sudoers.d/90-alarm
alarm ALL=(ALL) NOPASSWD:ALL
SUDOERS
chmod 0440 /etc/sudoers.d/90-alarm
cat <<'SERVICE' > /etc/systemd/system/weston-drm.service
[Unit]
Description=Weston DRM compositor (alarm)
After=seatd.service systemd-user-sessions.service
Wants=seatd.service

[Service]
Type=simple
User=alarm
WorkingDirectory=/home/alarm
Environment=XDG_RUNTIME_DIR=/run/weston
Environment=WAYLAND_DISPLAY=wayland-0
ExecStartPre=/usr/bin/install -d -m 0700 -o alarm -g alarm /run/weston
ExecStart=/usr/bin/weston --backend=drm-backend.so --tty=1 --log=/tmp/weston.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE
chmod 0644 /etc/systemd/system/weston-drm.service
export SYSTEMD_OFFLINE=1
systemctl enable seatd.service
systemctl enable weston-drm.service
CHROOT
	local chroot_rc=$?
	set -e
	remove_qemu_static
	restore_chroot_resolv_conf
	umount_chroot_fs
	if [[ ${chroot_rc} -ne 0 ]]; then
		log "error: rootfs customization failed"
		exit "${chroot_rc}"
	fi
}

customize_rootfs

log "packaging rootfs to ${OUTPUT_PATH}"
bsdtar -cpf - -C "${ROOTFS_DIR}" . | gzip -c > "${OUTPUT_PATH}"
log "rootfs tarball ready at ${OUTPUT_PATH}"
write_rootfs_size_metadata
