#!/usr/bin/env bash
set -euo pipefail

log() {
	printf '[yocto] %s\n' "$*" >&2
}

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
YOCTO_DIR=${YOCTO_DIR:-"${ROOT_DIR}/yocto"}
POKY_DIR="${YOCTO_DIR}/poky"
META_OE_DIR="${YOCTO_DIR}/meta-openembedded"
META_SUNXI_DIR="${YOCTO_DIR}/meta-sunxi"
META_ARM_DIR="${YOCTO_DIR}/meta-arm"
META_BANAPRO_DIR="${ROOT_DIR}/meta-banapro"

POKY_REPO=${POKY_REPO:-"https://git.yoctoproject.org/git/poky"}
POKY_BRANCH=${POKY_BRANCH:-"scarthgap"}
META_OE_REPO=${META_OE_REPO:-"https://github.com/openembedded/meta-openembedded.git"}
META_OE_BRANCH=${META_OE_BRANCH:-"scarthgap"}
META_SUNXI_REPO=${META_SUNXI_REPO:-"https://github.com/linux-sunxi/meta-sunxi.git"}
META_SUNXI_BRANCH=${META_SUNXI_BRANCH:-"scarthgap"}
META_ARM_REPO=${META_ARM_REPO:-"https://git.yoctoproject.org/git/meta-arm"}
META_ARM_BRANCH=${META_ARM_BRANCH:-"scarthgap"}

BUILD_DIR=${YOCTO_BUILD_DIR:-"${YOCTO_DIR}/build-banapro"}
BITBAKE_IMAGE=${BITBAKE_IMAGE:-"banapro-image"}

APT_PACKAGES=(
	gawk wget git diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio
	python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git
	python3-jinja2 libegl1-mesa libsdl1.2-dev pylint xterm tar locales bmap-tools lz4
)

ensure_packages() {
	if command -v apt-get >/dev/null 2>&1; then
		local missing=()
		for pkg in "${APT_PACKAGES[@]}"; do
			if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
				missing+=("$pkg")
			fi
		done
		if ((${#missing[@]} == 0)); then
			log "all host dependencies already installed"
			return
		fi
		log "installing missing host dependencies via apt-get: ${missing[*]}"
		sudo apt-get update
		sudo apt-get install -y "${missing[@]}"
	else
		log "warning: apt-get not found – please install Yocto host deps manually"
	fi
}

clone_repo() {
	local dir="$1" url="$2" branch="$3"
	if [[ -d "${dir}/.git" ]]; then
		log "updating $(basename "${dir}")"
		git -C "${dir}" fetch origin
		git -C "${dir}" checkout "${branch}"
		git -C "${dir}" pull --ff-only origin "${branch}"
	else
		log "cloning $(basename "${dir}") (${branch})"
		git clone --branch "${branch}" "${url}" "${dir}"
	fi
}

run_bitbake_cmd() {
	local cmd="$1"
	bash -lc "source '${POKY_DIR}/oe-init-build-env' '${BUILD_DIR}' >/dev/null && ${cmd}"
}

ensure_layer() {
	local layer_path="$1"
	local check_cmd="source '${POKY_DIR}/oe-init-build-env' '${BUILD_DIR}' >/dev/null && bitbake-layers show-layers"
	if ! bash -lc "${check_cmd} | awk '{print \$2}' | grep -Fxq '${layer_path}'"; then
		log "adding layer ${layer_path}"
		bash -lc "source '${POKY_DIR}/oe-init-build-env' '${BUILD_DIR}' >/dev/null && bitbake-layers add-layer '${layer_path}'"
	else
		log "layer already present: ${layer_path}"
	fi
}

ensure_conf_line() {
	local file="$1"
	local line="$2"
	grep -Fqx "${line}" "${file}" 2>/dev/null || echo "${line}" >> "${file}"
}

main() {
	command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
	ensure_packages

	mkdir -p "${YOCTO_DIR}"
	clone_repo "${POKY_DIR}" "${POKY_REPO}" "${POKY_BRANCH}"
	clone_repo "${META_OE_DIR}" "${META_OE_REPO}" "${META_OE_BRANCH}"
	clone_repo "${META_SUNXI_DIR}" "${META_SUNXI_REPO}" "${META_SUNXI_BRANCH}"
	clone_repo "${META_ARM_DIR}" "${META_ARM_REPO}" "${META_ARM_BRANCH}"

	[[ -d "${META_BANAPRO_DIR}" ]] || { echo "meta-banapro layer not found at ${META_BANAPRO_DIR}" >&2; exit 1; }

	log "initialising build directory ${BUILD_DIR}"
	run_bitbake_cmd ":"

	local local_conf="${BUILD_DIR}/conf/local.conf"
	local bblayers_conf="${BUILD_DIR}/conf/bblayers.conf"

	ensure_conf_line "${local_conf}" 'MACHINE ??= "bananapro"'
	ensure_conf_line "${local_conf}" 'DISTRO ??= "banapro"'
	ensure_conf_line "${local_conf}" "BB_NUMBER_THREADS ?= \"$(nproc)\""
	ensure_conf_line "${local_conf}" "PARALLEL_MAKE ?= \"-j $(nproc)\""

	ensure_layer "${POKY_DIR}/meta"
	ensure_layer "${POKY_DIR}/meta-poky"
	ensure_layer "${POKY_DIR}/meta-yocto-bsp"
	ensure_layer "${META_OE_DIR}/meta-oe"
	ensure_layer "${META_OE_DIR}/meta-python"
	ensure_layer "${META_ARM_DIR}/meta-arm-toolchain"
	ensure_layer "${META_ARM_DIR}/meta-arm"
	ensure_layer "${META_SUNXI_DIR}"
	ensure_layer "${META_BANAPRO_DIR}"

	log "building ${BITBAKE_IMAGE}"
	run_bitbake_cmd "bitbake ${BITBAKE_IMAGE}"

	log "build complete. See ${BUILD_DIR}/tmp/deploy/images/bananapro for artifacts."
}

main "$@"
