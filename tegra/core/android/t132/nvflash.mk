# Packages required to run 'nvflash' for any T132 board

$(call inherit-product, $(LOCAL_PATH)/../bootloader/tboot-tk.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/warmboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvbootloader.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvflash.mk)

PRODUCT_PACKAGES += \
    mts_preboot_si \
    mts_si \
    mts_preboot_prod \
    mts_prod \
    xusb_sil_rel_fw
