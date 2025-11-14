#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPOS_DIR="${ROOT_DIR}/repos"
LINUX_DIR="${REPOS_DIR}/linux"
UBOOT_DIR="${REPOS_DIR}/u-boot"
DTO_DIR="${REPOS_DIR}/dt-overlays"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/banapro"
MODULES_INSTALL="${ARTIFACTS_DIR}/modules"
HEADERS_INSTALL="${ARTIFACTS_DIR}/headers"
BOARD_DTB="${BOARD_DTB:-sun7i-a20-bananapro.dtb}"
UBOOT_DEFCONFIG="${UBOOT_DEFCONFIG:-Bananapro_defconfig}"
LCD_DTBO="${LCD_DTBO:-bpi-m1p-lcd.dtbo}"
PATCH_FILE="${ROOT_DIR}/patches/0001_dt-overlays-include-arm-dts.patch"
JOBS="${JOBS:-$(nproc)}"
APT_PKGS=(
	#!/usr/bin/env bash
	set -euo pipefail

	SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
	exec "${SCRIPT_DIR}/banapro.sh" build "$@"

