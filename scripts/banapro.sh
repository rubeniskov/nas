#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/banapro/common.sh"
source "${SCRIPT_DIR}/banapro/kernel.sh"
source "${SCRIPT_DIR}/banapro/uboot.sh"

LAST_ROOTFS_TAR=""

usage() {
	cat <<'EOF'
Usage: banapro.sh <command> [args]

Commands:
  build               Build kernel, overlays, U-Boot, rootfs, and SD image.
  build-kernel        Build only the Linux kernel + overlays.
  build-uboot         Build only U-Boot.
  build-rootfs [args] Build the Arch rootfs tarball via scripts/banapro/rootfs.sh (requires sudo).
  build-image         Build an Arch Linux ARM SD image; defaults to latest rootfs (requires sudo).
  kernel-menuconfig   Run menuconfig for the kernel tree.
  uboot-menuconfig    Run menuconfig for the U-Boot tree.
  fetch-deps          Install host packages and sync required git repositories.
  help                Show this help.
EOF
}

cmd_fetch_deps() {
	ensure_packages
	mkdir -p "${REPOS_DIR}" "${ARTIFACTS_DIR}"
	ensure_repo "${LINUX_DIR}" git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "${LINUX_REV}"
	ensure_repo "${DTO_DIR}" https://github.com/wens/dt-overlays.git "${DTO_REV}"
	ensure_repo "${UBOOT_DIR}" git://git.denx.de/u-boot.git "${UBOOT_REV}"
	apply_linux_patches
	apply_dto_patch
}

cmd_build_kernel() {
	cmd_fetch_deps
	kernel_configure
	kernel_build
	kernel_install_artifacts
	kernel_build_overlay
}

cmd_build_uboot() {
	cmd_fetch_deps
	uboot_configure
	uboot_build
}

cmd_build_all() {
	cmd_fetch_deps
	kernel_build_all
	uboot_build_all
	run_rootfs_builder
	run_image_builder
}

run_rootfs_builder() {
	mkdir -p "${ARTIFACTS_DIR}"
	local args=("$@")
	local output_path=""
	for ((i=0; i<${#args[@]}; ++i)); do
		if [[ "${args[i]}" == "--output" && $((i+1)) -lt ${#args[@]} ]]; then
			output_path="${args[i+1]}"
			break
		fi
	done
	if [[ -z "${output_path}" ]]; then
		output_path="${ARTIFACTS_DIR}/rootfs/banapro-rootfs.tar.gz"
		args+=(--output "${output_path}")
	fi
	output_path=$(readlink -m "${output_path}")
	sudo BANAPRO_ARTIFACTS_DIR="${ARTIFACTS_DIR}" "${SCRIPT_DIR}/banapro/rootfs.sh" "${args[@]}"
	LAST_ROOTFS_TAR="${output_path}"
	export BANAPRO_ROOTFS_TAR="${output_path}"
}

run_image_builder() {
	mkdir -p "${ARTIFACTS_DIR}"
	local args=("$@")
	local has_rootfs=0
	local image_path=""
	local tgz_path=""
	for ((i=0; i<${#args[@]}; ++i)); do
		case "${args[i]}" in
			--rootfs-tar)
				has_rootfs=1
				((i++))
				;;
			--image)
				if [[ $((i+1)) -lt ${#args[@]} ]]; then
					image_path="${args[i+1]}"
					((i++))
				fi
				;;
			--tgz)
				if [[ $((i+1)) -lt ${#args[@]} ]]; then
					tgz_path="${args[i+1]}"
					((i++))
				fi
				;;
		esac
	done
	if [[ ${has_rootfs} -eq 0 ]]; then
		local rootfs_src="${BANAPRO_ROOTFS_TAR:-${LAST_ROOTFS_TAR:-}}"
		if [[ -z "${rootfs_src}" ]]; then
			echo "build-image requires --rootfs-tar <path>; run build-rootfs first or set BANAPRO_ROOTFS_TAR." >&2
			return 1
		fi
		args+=(--rootfs-tar "${rootfs_src}")
	fi
	if [[ -z "${image_path}" ]]; then
		image_path="${ARTIFACTS_DIR}/archlinuxarm-bananapro.img"
		args+=(--image "${image_path}")
	fi
	if [[ -z "${tgz_path}" ]]; then
		args+=(--tgz "${image_path}.tgz")
	fi
	sudo BANAPRO_ARTIFACTS_DIR="${ARTIFACTS_DIR}" "${SCRIPT_DIR}/banapro/image.sh" "${args[@]}"
}

cmd_build_rootfs() {
	shift || true
	run_rootfs_builder "$@"
}

cmd_build_image() {
	shift || true
	run_image_builder "$@"
}

cmd_kernel_menuconfig() {
	cmd_fetch_deps
	kernel_menuconfig
}

cmd_uboot_menuconfig() {
	cmd_fetch_deps
	uboot_menuconfig
}

COMMAND="${1:-help}"
case "${COMMAND}" in
	build)
		cmd_build_all
		;;
	build-kernel)
		cmd_build_kernel
		;;
	build-uboot)
		cmd_build_uboot
		;;
	build-rootfs)
		cmd_build_rootfs "$@"
		;;
	build-image)
		cmd_build_image "$@"
		;;
	kernel-menuconfig)
		cmd_kernel_menuconfig
		;;
	uboot-menuconfig)
		cmd_uboot_menuconfig
		;;
	fetch-deps)
		cmd_fetch_deps
		;;
	help|-h|--help)
		usage
		;;
	*)
		usage
		exit 1
		;;
 esac
