#!/usr/bin/env bash

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
REPOS_DIR="${ROOT_DIR}/repos"
LINUX_DIR="${REPOS_DIR}/linux"
UBOOT_DIR="${REPOS_DIR}/u-boot"
DTO_DIR="${REPOS_DIR}/dt-overlays"
LINUX_REV="${LINUX_REV:-6da43bbeb6918164f7287269881a5f861ae09d7e}"
DTO_REV="${DTO_REV:-0a480fd3601e308100d6aedf8da4aa9a1b81cbcd}"
UBOOT_REV="${UBOOT_REV:-6c2f2d9aa63d1642dffae7d7ac88f7ae879e13d1}"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/banapro"
MODULES_INSTALL="${ARTIFACTS_DIR}/modules"
HEADERS_INSTALL="${ARTIFACTS_DIR}/headers"
BOARD_DTB="${BOARD_DTB:-sun7i-a20-bananapro.dtb}"
UBOOT_DEFCONFIG="${UBOOT_DEFCONFIG:-Bananapro_defconfig}"
LCD_DTBO="${LCD_DTBO:-bpi-m1p-lcd.dtbo}"
PATCH_FILE="${ROOT_DIR}/patches/0001_dt-overlays-include-arm-dts.patch"
JOBS="${JOBS:-$(nproc)}"
APT_PKGS=()
APT_PKGS+=(gcc-arm-linux-gnueabihf flex bison bc libssl-dev make git wget)
APT_PKGS+=(device-tree-compiler u-boot-tools swig python3-dev python3-setuptools)
APT_PKGS+=(libgnutls28-dev libncurses-dev libarchive-tools rsync dosfstools util-linux e2fsprogs)

log() { printf '[banapro] %s\n' "$*" >&2; }

ensure_packages() {
	if command -v apt-get >/dev/null 2>&1; then
		log "ensuring host packages: ${APT_PKGS[*]}"
		sudo apt-get update
		sudo apt-get install -y "${APT_PKGS[@]}"
	else
		log "apt-get not found; install prerequisites manually"
	fi
}

ensure_repo() {
	local path="$1"
	local url="$2"
	local rev="${3:-}"
	if [[ ! -d "${path}/.git" ]]; then
		log "cloning ${url}"
		git clone "${url}" "${path}"
	fi
	if [[ -z "${rev}" ]]; then
		log "updating ${path}"
		git -C "${path}" pull --ff-only
	else
		log "ensuring ${path} at ${rev}"
		git -C "${path}" fetch origin --tags
		git -C "${path}" fetch origin "${rev}" || true
		git -C "${path}" checkout --detach "${rev}"
		git -C "${path}" reset --hard "${rev}"
	fi
}

apply_dto_patch() {
	if [[ ! -f "${PATCH_FILE}" ]]; then
		log "patch file ${PATCH_FILE} missing; skipping"
		return
	fi

	if git -C "${DTO_DIR}" apply --check --reverse "${PATCH_FILE}" >/dev/null 2>&1; then
		log "dt-overlays patch already applied"
	else
		log "applying dt-overlays patch"
		git -C "${DTO_DIR}" apply "${PATCH_FILE}"
	fi
}

copy_dtb() {
	local dtb_name="$1"
	local primary_path="${LINUX_DIR}/arch/arm/boot/dts/${dtb_name}"

	if [[ -f "${primary_path}" ]]; then
		cp "${primary_path}" "${ARTIFACTS_DIR}/"
		return
	fi

	local located_path
	located_path=$(find "${LINUX_DIR}/arch/arm/boot/dts" -name "${dtb_name}" -print -quit)
	if [[ -n "${located_path}" ]]; then
		log "located ${dtb_name} at ${located_path#${LINUX_DIR}/}"
		cp "${located_path}" "${ARTIFACTS_DIR}/"
	else
		log "error: DTB ${dtb_name} not found"
		return 1
	fi
}

resolve_uboot_defconfig() {
	local requested="$1"
	local exact_path="${UBOOT_DIR}/configs/${requested}"

	if [[ -f "${exact_path}" ]]; then
		printf '%s' "${requested}"
		return
	fi

	local located
	located=$(find "${UBOOT_DIR}/configs" -maxdepth 1 -type f -iname "${requested}" -print -quit)
	if [[ -n "${located}" ]]; then
		basename "${located}"
		return
	fi

	log "error: U-Boot defconfig ${requested} not found"
	return 1
}
