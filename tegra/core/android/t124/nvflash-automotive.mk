# Packages required to run 'nvflash' for any p1859/p1889 board

$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvflash.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/quickboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/qb-flash-tools.mk)

PRODUCT_PACKAGES += \
    xusb_sil_rel_fw
