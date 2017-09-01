LOCAL_OEMCRYPTO_LEVEL := 3
PRODUCT_PACKAGES += \
    com.google.widevine.software.drm \
    com.google.widevine.software.drm.xml \
    libdrmdecrypt \
    libdrmwvmcommon \
    liboemcrypto \
    libwvdrm_L$(LOCAL_OEMCRYPTO_LEVEL) \
    libwvmcommon \
    libwvocs_L$(LOCAL_OEMCRYPTO_LEVEL) \
    libWVStreamControlAPI_L$(LOCAL_OEMCRYPTO_LEVEL) \
    libwvdrmengine \
    test-libwvm \
    test-wvdrmplugin \
    test-wvplayer_L$(LOCAL_OEMCRYPTO_LEVEL) \
    oemcrypto_test
