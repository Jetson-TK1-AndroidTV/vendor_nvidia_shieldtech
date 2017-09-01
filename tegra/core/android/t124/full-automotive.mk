# Packages required for any p1859/p1889 board

$(call inherit-product, $(LOCAL_PATH)/boot.mk)
$(call inherit-product, $(LOCAL_PATH)/nvflash-automotive.mk)
$(call inherit-product, $(LOCAL_PATH)/../camera/full.mk)
$(call inherit-product, $(LOCAL_PATH)/../compute/cuda.mk)
$(call inherit-product, $(LOCAL_PATH)/../compute/renderscript.mk)
$(call inherit-product, $(LOCAL_PATH)/../compute/compiler.mk)
$(call inherit-product, $(LOCAL_PATH)/../graphics/full.mk)
$(call inherit-product, $(LOCAL_PATH)/../icera/full.mk)
$(call inherit-product, $(LOCAL_PATH)/../multimedia/full.mk)
$(call inherit-product, $(LOCAL_PATH)/../services/pbc.mk)
$(call inherit-product, $(LOCAL_PATH)/../services/ussrd.mk)
$(call inherit-product, $(LOCAL_PATH)/../tests/full.mk)
$(call inherit-product, $(LOCAL_PATH)/../touch/raydium.mk)
$(call inherit-product, $(LOCAL_PATH)/../touch/synaptics.mk)

PRODUCT_PACKAGES += \
    tegra_xusb_firmware \
    tegra12x_xusb_firmware \
    libnvcpl \
    com.nvidia.NvCPLSvc.api
