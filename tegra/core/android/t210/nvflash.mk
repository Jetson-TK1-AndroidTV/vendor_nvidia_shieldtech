# Packages required to run 'nvflash' for any T210 board

$(call inherit-product, $(LOCAL_PATH)/../bootloader/tboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/warmboot.mk)
$(call inherit-product, $(LOCAL_PATH)/../bootloader/cboot.mk)

PRODUCT_PACKAGES += \
    xusb_sil_rel_fw \
    tnspec \
    nvtegrasign \
    nvtegrasecuretool \
    nvkeystoregen \
    nvblob_v2
