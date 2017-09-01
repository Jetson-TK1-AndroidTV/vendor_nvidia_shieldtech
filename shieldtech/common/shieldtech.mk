# NVIDIA Tegra124 development system
#
# Copyright (c) 2017 NVIDIA Corporation.  All rights reserved.


BOARD_USES_SHIELDTECH := true

# Add support for Controller menu
PRODUCT_COPY_FILES += \
    vendor/nvidia/shieldtech/common/etc/com.nvidia.shieldtech.xml:system/etc/permissions/com.nvidia.shieldtech.xml

# RSMouse
ifneq ($(SHIELDTECH_FEATURE_RSMOUSE),false)
# Feature cannot be disabled
endif


# Controller-based Keyboard
ifneq ($(SHIELDTECH_FEATURE_KEYBOARD),false)
PRODUCT_PACKAGES += \
  NVLatinIME \
  libjni_nvlatinime
endif

# Full-screen Mode
ifneq ($(SHIELDTECH_FEATURE_FULLSCREEN),false)
DEVICE_PACKAGE_OVERLAYS += vendor/nvidia/shieldtech/common/feature_overlays/fullscreen_mode
endif

# Console Mode
ifneq ($(SHIELDTECH_FEATURE_CONSOLE_MODE),false)
DEVICE_PACKAGE_OVERLAYS += vendor/nvidia/shieldtech/common/feature_overlays/console_mode
PRODUCT_PACKAGES += \
  ConsoleUI \
  ConsoleSplash
endif

# Blake controller
ifneq ($(SHIELDTECH_FEATURE_BLAKE),true)
#DEVICE_PACKAGE_OVERLAYS += vendor/nvidia/shieldtech/common/feature_overlays/blake
PRODUCT_PACKAGES += \
  blake \
  lota \
  libaudiostats \
  libaudiopolicymanager \
  audio.nvrc.tegra \
  audio.nvwc.tegra \
  hdmi_cec.tegra
endif

# NvAndroidOSC
ifneq ($(SHIELDTECH_FEATURE_OSC),false)
DEVICE_PACKAGE_OVERLAYS += vendor/nvidia/shieldtech/common/feature_overlays/android_osc
PRODUCT_PACKAGES += \
  NvAndroidOSC
endif

# Gallery
ifeq ($(SHIELDTECH_FEATURE_NVGALLERY),true)
PRODUCT_PACKAGES += \
  NVGallery \
  libnvjni_eglfence \
  libnvjni_filtershow_filters \
  libnvjni_mosaic
endif

# Generic ShieldTech Features
# DEVICE_PACKAGE_OVERLAYS += vendor/nvidia/shieldtech/common/overlay

# Apk ConsoleUI
PRODUCT_PACKAGES += \
     NvShieldTech \
     NvRpxService \
     PrebuiltShieldRemoteService

# Audio hals
PRODUCT_PACKAGES += \
    audio.nvrc.tegra \
    audio.nvwc.tegra

# Libs
PRODUCT_PACKAGES += \
    libfirmwareupdate \
    liblota \
    libhidraw \
    libnvhwc_service \
    libshieldtech \
    libadaptordecoder \
    libaudiostats \
    libaudiopolicymanager \
    audio.nvrc.tegra \
    audio.nvwc.tegra \
    hdmi_cec.tegra

# Media files
PRODUCT_COPY_FILES += \
    vendor/nvidia/shieldtech/common/media/sync_test.mp4:system/vendor/oem/media/sync_test.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_finish_BLAKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_finish_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_finish_JARVIS.mp4:system/vendor/oem/media/blakepairing/ota/ota_finish_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_finish_PEPPER.mp4:system/vendor/oem/media/blakepairing/ota/ota_finish_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_finish_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_finish_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_loop_BLAKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_loop_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_loop_JARVIS.mp4:system/vendor/oem/media/blakepairing/ota/ota_loop_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_loop_PEPPER.mp4:system/vendor/oem/media/blakepairing/ota/ota_loop_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_loop_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_loop_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_start_BLAKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_start_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_start_JARVIS.mp4:system/vendor/oem/media/blakepairing/ota/ota_start_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_start_PEPPER.mp4:system/vendor/oem/media/blakepairing/ota/ota_start_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/ota/ota_start_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/ota/ota_start_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_connecting_BLAKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_connecting_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_connecting_JARVIS.mp4:system/vendor/oem/media/blakepairing/pairing/pair_connecting_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_connecting_PEPPER.mp4:system/vendor/oem/media/blakepairing/pairing/pair_connecting_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_connecting_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_connecting_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_error_BLAKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_error_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_error_JARVIS.mp4:system/vendor/oem/media/blakepairing/pairing/pair_error_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_error_PEPPER.mp4:system/vendor/oem/media/blakepairing/pairing/pair_error_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_error_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_error_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_success_BLAKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_success_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_success_JARVIS.mp4:system/vendor/oem/media/blakepairing/pairing/pair_success_JARVIS.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_success_PEPPER.mp4:system/vendor/oem/media/blakepairing/pairing/pair_success_PEPPER.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_success_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_success_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_found_BLAKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_found_BLAKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_found_THUNDERSTRIKE.mp4:system/vendor/oem/media/blakepairing/pairing/pair_found_THUNDERSTRIKE.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_loop.mp4:system/vendor/oem/media/blakepairing/pairing/pair_loop.mp4 \
    vendor/nvidia/shieldtech/common/media/blakepairing/pairing/pair_start.mp4:system/vendor/oem/media/blakepairing/pairing/pair_start.mp4
