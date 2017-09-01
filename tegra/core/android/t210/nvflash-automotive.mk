# Packages required to run 'nvflash' for vcm31t210

$(call inherit-product, $(LOCAL_PATH)/../bootloader/tboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvflash.mk)
#$(call inherit-product, $(LOCAL_PATH)/../bootloader/quickboot.mk)
#$(call inherit-product, $(LOCAL_PATH)/../bootloader/qb-flash-tools.mk)

PRODUCT_PACKAGES += \
    xusb_sil_rel_fw
