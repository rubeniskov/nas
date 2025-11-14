#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

kernel_configure() {
	log "configuring kernel (sunxi_defconfig)"
	make -C "${LINUX_DIR}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" sunxi_defconfig
}

kernel_menuconfig() {
	make -C "${LINUX_DIR}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
}

kernel_build() {
	log "building kernel (zImage, dtbs, modules)"
	local dtc_flags="${DTC_FLAGS:+${DTC_FLAGS} }-@"
	make -C "${LINUX_DIR}" \
		ARCH="${ARCH}" \
		CROSS_COMPILE="${CROSS_COMPILE}" \
		DTC_FLAGS="${dtc_flags}" \
		-j"${JOBS}" zImage dtbs modules
}

kernel_install_artifacts() {
	log "installing modules to ${MODULES_INSTALL}"
	rm -rf "${MODULES_INSTALL}"
	make -C "${LINUX_DIR}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${MODULES_INSTALL}" modules_install

	log "installing headers to ${HEADERS_INSTALL}"
	rm -rf "${HEADERS_INSTALL}"
	make -C "${LINUX_DIR}" ARCH="${ARCH}" INSTALL_HDR_PATH="${HEADERS_INSTALL}" headers_install

	mkdir -p "${ARTIFACTS_DIR}"
	cp "${LINUX_DIR}/arch/arm/boot/zImage" "${ARTIFACTS_DIR}/"
	copy_dtb "${BOARD_DTB}"
}

kernel_build_overlay() {
	log "building LCD overlay (${LCD_DTBO})"
	local dtc_flags="${DTC_FLAGS:+${DTC_FLAGS} }-@"
	make -C "${DTO_DIR}" \
		KERNEL_SRC="${LINUX_DIR}" \
		DT_OVERLAYS="${LCD_DTBO}" \
		DTC_FLAGS="${dtc_flags}"
	if [[ -f "${DTO_DIR}/${LCD_DTBO}" ]]; then
		mkdir -p "${ARTIFACTS_DIR}"
		cp "${DTO_DIR}/${LCD_DTBO}" "${ARTIFACTS_DIR}/"
	else
		log "warning: overlay ${LCD_DTBO} not produced"
	fi
}

kernel_build_all() {
	kernel_configure
	kernel_build
	kernel_install_artifacts
	kernel_build_overlay
}
