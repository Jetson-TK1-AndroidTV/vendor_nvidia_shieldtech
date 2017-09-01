$(call inherit-product, $(LOCAL_PATH)/base.mk)
$(call inherit-product, $(LOCAL_PATH)/firmware.mk)
$(call inherit-product, $(LOCAL_PATH)/nvsi.mk)
$(call inherit-product, $(LOCAL_PATH)/widevine.mk)
$(call inherit-product, $(LOCAL_PATH)/tests.mk)
ifneq ($(TARGET_BUILD_VARIANT),user)
$(call inherit-product, $(LOCAL_PATH)/sample.mk)
endif
