$(call inherit-product, $(LOCAL_PATH)/core.mk)
$(call inherit-product, $(LOCAL_PATH)/camera.mk)

PRODUCT_PACKAGES += \
	python_source_files \
	python_nvcamera_scripts
