# Packages required to run 'nvflash' for any T124 board

$(call inherit-product, $(LOCAL_PATH)/../bootloader/tboot-tk.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/warmboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvbootloader.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/nvflash.mk)

PRODUCT_PACKAGES += \
    xusb_sil_rel_fw
