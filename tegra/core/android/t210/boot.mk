# Packages necessary to create boot&system images, flash with fastboot, and
# boot to desktop

$(call inherit-product,$(LOCAL_PATH)/../graphics/boot.mk)

PRODUCT_PACKAGES += \
    NETA_img.bin \
    gpu2cde.bin
