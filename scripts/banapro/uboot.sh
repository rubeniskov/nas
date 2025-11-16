#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

UBOOT_ENABLE_LCD_CONFIG=${UBOOT_ENABLE_LCD_CONFIG:-1}
UBOOT_LCD_MODE=${UBOOT_LCD_MODE:-'x:800,y:480,depth:24,pclk_khz:30000,le:40,ri:40,up:29,lo:13,hs:48,vs:3,sync:3,vmode:0'}
UBOOT_LCD_POWER=${UBOOT_LCD_POWER:-'PH12'}
UBOOT_LCD_BL_EN=${UBOOT_LCD_BL_EN:-'PH8'}
UBOOT_LCD_BL_PWM=${UBOOT_LCD_BL_PWM:-'PB2'}

declare -a UBOOT_LCD_CONFIG_OVERRIDES=(
	"CONFIG_VIDEO_SUNXI=y"
	"CONFIG_VIDEO=y"
	"CONFIG_DM_VIDEO=y"
	"CONFIG_DISPLAY=y"
	"CONFIG_CONSOLE_MUX=y"
	"CONFIG_VIDEO_LCD_MODE=\"${UBOOT_LCD_MODE}\""
	"CONFIG_VIDEO_LCD_POWER=\"${UBOOT_LCD_POWER}\""
	"CONFIG_VIDEO_LCD_BL_EN=\"${UBOOT_LCD_BL_EN}\""
	"CONFIG_VIDEO_LCD_BL_PWM=\"${UBOOT_LCD_BL_PWM}\""
	"CONFIG_VIDEO_LCD_BL_PWM_ACTIVE_LOW=n"
)

uboot_configure() {
	local defconfig
	defconfig=$(resolve_uboot_defconfig "${UBOOT_DEFCONFIG}")
	log "configuring U-Boot (${defconfig})"
	make -C "${UBOOT_DIR}" CROSS_COMPILE="${CROSS_COMPILE}" "${defconfig}"
	uboot_apply_lcd_config
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

uboot_apply_config_overrides() {
	local config_file="${UBOOT_DIR}/.config"
	[[ -f "${config_file}" ]] || {
		log "error: ${config_file} not found; run defconfig first"
		return 1
	}

	local entry key
	for entry in "$@"; do
		[[ -n "${entry}" ]] || continue
		key="${entry%%=*}"
		sed -i "/^${key}=.*/d" "${config_file}"
		sed -i "/^# ${key} is not set/d" "${config_file}"
		echo "${entry}" >>"${config_file}"
		log "  set ${entry}"
	done

	make -C "${UBOOT_DIR}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig >/dev/null
}

uboot_apply_lcd_config() {
	if [[ "${UBOOT_ENABLE_LCD_CONFIG}" != "0" ]]; then
		log "applying LCD configuration overrides"
		uboot_apply_config_overrides "${UBOOT_LCD_CONFIG_OVERRIDES[@]}"
	else
		log "LCD configuration overrides disabled"
	fi
}

uboot_build_all() {
	uboot_configure
	uboot_build
}
