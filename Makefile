# Convenience targets for building and flashing the Banana Pro Yocto image

YOCTO_HELPER ?= ./scripts/yocto_build.sh
BITBAKE_IMAGE ?= banapro-image
YOCTO_BUILD_DIR ?= $(CURDIR)/yocto/build-banapro
DEPLOY_DIR ?= $(YOCTO_BUILD_DIR)/tmp/deploy/images/bananapro
IMAGE_BASE ?= banapro-image-bananapro.rootfs
WIC_GZ ?= $(DEPLOY_DIR)/$(IMAGE_BASE).wic.gz
BMAP ?= $(DEPLOY_DIR)/$(IMAGE_BASE).wic.bmap
BMAPTOOL ?= bmaptool
SD_DEVICE ?=

.PHONY: help build flash check-device ensure-image

help:
	@echo "Available targets:"
	@echo "  make build             # Run Yocto helper script ($(YOCTO_HELPER))"
	@echo "  make flash SD_DEVICE=/dev/sdX  # Flash latest wic image to SD card using bmaptool"
	@echo "Variables: YOCTO_HELPER, BITBAKE_IMAGE, YOCTO_BUILD_DIR, DEPLOY_DIR, IMAGE_BASE, SD_DEVICE"

build:
	$(YOCTO_HELPER)

flash: check-device ensure-image
	sudo $(BMAPTOOL) copy --bmap "$(BMAP)" "$(WIC_GZ)" "$(SD_DEVICE)"
	sudo sync

check-device:
	@if [ -z "$(SD_DEVICE)" ]; then \
		echo "Set SD_DEVICE to the target block device (e.g. make flash SD_DEVICE=/dev/sdX)" >&2; \
		exit 1; \
	fi
	@if [ ! -b "$(SD_DEVICE)" ]; then \
		echo "Block device $(SD_DEVICE) not found" >&2; \
		exit 1; \
	fi

ensure-image:
	@if [ ! -f "$(WIC_GZ)" ]; then \
		echo "Missing $(WIC_GZ). Run 'make build' first." >&2; \
		exit 1; \
	fi
	@if [ ! -f "$(BMAP)" ]; then \
		echo "Missing $(BMAP). Run 'make build' first." >&2; \
		exit 1; \
	fi
