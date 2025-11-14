#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

uboot_configure() {
	local defconfig
	defconfig=$(resolve_uboot_defconfig "${UBOOT_DEFCONFIG}")
	log "configuring U-Boot (${defconfig})"
	make -C "${UBOOT_DIR}" CROSS_COMPILE="${CROSS_COMPILE}" "${defconfig}"
}

uboot_menuconfig() {
	make -C "${UBOOT_DIR}" CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
}

uboot_build() {
	log "building U-Boot"
	make -C "${UBOOT_DIR}" CROSS_COMPILE="${CROSS_COMPILE}" -j"${JOBS}"
	mkdir -p "${ARTIFACTS_DIR}"
	cp "${UBOOT_DIR}/u-boot-sunxi-with-spl.bin" "${ARTIFACTS_DIR}/"
	cp "${UBOOT_DIR}/u-boot.bin" "${ARTIFACTS_DIR}/"
}

uboot_build_all() {
	uboot_configure
	uboot_build
}
