SUMMARY = "Banana Pro reference image with DRM/LCD and networking"
DESCRIPTION = "Minimal reference image for the Banana Pro using mainline kernel, Weston, and LCD/backlight support."
LICENSE = "MIT"

require recipes-core/images/core-image-base.bb

IMAGE_FEATURES += "ssh-server-openssh package-management"

IMAGE_INSTALL:append = " \
    weston \
    seatd \
    kmscube \
    iproute2 \
    iputils \
    ethtool \
    iwd \
    wpa-supplicant \
    bluez5 \
    pulseaudio-server \
    alsa-utils \
    fbset \
"

# Provide a hook to inject additional packages from local.conf via EXTRA_IMAGE_FEATURES
