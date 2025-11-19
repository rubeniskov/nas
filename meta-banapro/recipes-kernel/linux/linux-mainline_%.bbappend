FILESEXTRAPATHS:prepend := "${THISDIR}/linux-banapro:"

SRC_URI:append:bananapro = " \
    file://0002_sun7i-a20-bananapro-cpu-clock.patch \
    file://0003_sunxi-defconfig-landlock.patch \
    file://0005_panel-simple-bananapi-connector-type.patch \
    file://bpi-m1p-lcd.dts \
    file://drm-banapro.cfg \
"

DEPENDS:append:bananapro = " dtc-native"

do_compile:append:bananapro() {
    install -d ${B}/arch/arm/boot/dts/overlays
    overlay_pp=${B}/arch/arm/boot/dts/overlays/bpi-m1p-lcd.preprocessed.dts
    ${CPP} -nostdinc -undef -D__DTS__ -x assembler-with-cpp -P \
        -I${S}/include -I${B}/arch/arm/boot/dts \
        ${WORKDIR}/bpi-m1p-lcd.dts > ${overlay_pp}

    dtc -@ -I dts -O dtb \
        -o ${B}/arch/arm/boot/dts/overlays/bpi-m1p-lcd.dtbo \
        ${overlay_pp}
}

do_install:append:bananapro() {
    install -d ${D}/boot/overlays
    install -m 0644 ${B}/arch/arm/boot/dts/overlays/bpi-m1p-lcd.dtbo \
        ${D}/boot/overlays/bpi-m1p-lcd.dtbo
}

do_deploy:append:bananapro() {
    install -m 0644 ${B}/arch/arm/boot/dts/overlays/bpi-m1p-lcd.dtbo \
        ${DEPLOYDIR}/bpi-m1p-lcd.dtbo
}
