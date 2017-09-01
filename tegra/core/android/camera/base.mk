PRODUCT_PACKAGES += \
    camera.tegra:32

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../include/ft/model_frontalface.xml:$(TARGET_COPY_OUT_VENDOR)/etc/model_frontal.xml:nvidia
