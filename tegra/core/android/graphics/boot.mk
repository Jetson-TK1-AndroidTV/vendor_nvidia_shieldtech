PRODUCT_PACKAGES += \
    gralloc.tegra \
    hwcomposer.tegra \
    memtrack.tegra \
    libglcore \
    libnvrmapi_tegra \
    libnvrm_gpu \
    libEGL_tegra \
    libGLESv1_CM_tegra \
    libGLESv2_tegra

ifeq ($(TARGET_BUILD_VARIANT), eng)
    # Google SW renderer, used in bringup
    PRODUCT_PACKAGES += \
        libGLES_android
endif

PRODUCT_PACKAGES += \
    NETB_img.bin \
    NETC_img.bin \
    gpmu_ucode.bin \
    fecs.bin \
    gpccs.bin \
    acr_ucode.bin \
    pmu_bl.bin \
    gpmu_ucode_image.bin \
    gpmu_ucode_desc.bin \
    pmu_sig.bin \
    fecs_sig.bin
