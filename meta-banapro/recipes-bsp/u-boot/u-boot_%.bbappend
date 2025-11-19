FILESEXTRAPATHS:prepend := "${THISDIR}/u-boot-banapro:"

SRC_URI:append:bananapro = " \
    file://lcd.cfg \
    file://boot-banapro.cmd \
"

do_configure:append:bananapro() {
    printf "Applying BananaPro LCD fragment to U-Boot configuration\n"
    config_dir="${B}"
    if [ ! -f "${config_dir}/.config" ]; then
        cfg_file=$(find "${B}" -maxdepth 2 -type f -name '.config' | head -n1 || true)
        if [ -n "${cfg_file}" ]; then
            config_dir=$(dirname "${cfg_file}")
        fi
    fi
    base_config="${config_dir}/.config"
    [ -f "${base_config}" ] || bbfatal "Unable to locate U-Boot base config at ${base_config}"
    cp ${WORKDIR}/lcd.cfg ${config_dir}/banapro-lcd.cfg
    ${S}/scripts/kconfig/merge_config.sh -m -O ${config_dir} ${base_config} ${config_dir}/banapro-lcd.cfg
    oe_runmake -C ${S} O=${config_dir} olddefconfig
}

# Binman calls ${B}/tools/mkimage directly, but multi-config builds place host
# tools under ${B}/${config}/tools. Provide a stable shim so mkimage is always
# reachable even before the per-config tree exists.
do_compile:prepend:bananapro() {
    install -d ${B}/tools
    if [ ! -x "${B}/tools/mkimage" ]; then
        if [ -x "${STAGING_BINDIR_NATIVE}/uboot-mkimage" ]; then
            ln -sf ${STAGING_BINDIR_NATIVE}/uboot-mkimage ${B}/tools/mkimage
        else
            bbfatal "Expected uboot-mkimage in ${STAGING_BINDIR_NATIVE}"
        fi
    fi

    # Override the default meta-sunxi boot.cmd with our BananaPro-specific script
    install -m 0644 ${WORKDIR}/boot-banapro.cmd ${WORKDIR}/boot.cmd
}
