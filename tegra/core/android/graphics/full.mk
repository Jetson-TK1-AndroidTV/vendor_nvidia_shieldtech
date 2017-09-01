$(call inherit-product, $(LOCAL_PATH)/boot.mk)
$(call inherit-product, $(LOCAL_PATH)/tests.mk)

PRODUCT_PACKAGES += \
    com.nvidia.display \
    com.nvidia.graphics \
    nvidia_display

# Most of these should have dependencies from elsewhere, and don't need to be here
PRODUCT_PACKAGES += \
    libnvblit \
    libnvcms \
    libnvddk_2d_v2 \
    libnvdrawpath \
    libnvglsi \
    libnvidia_display_jni \
    libnvwinsys \
    libnvwsi \
    libnvddk_vic
