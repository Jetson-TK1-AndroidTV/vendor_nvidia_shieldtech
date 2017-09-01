PRODUCT_PACKAGES += \
    libaudiopolicymanager:32 \
    audio.primary.tegra:32 \
    audio.a2dp.default:32 \
    audio.usb.default:32 \
    audio.nvwc.tegra:32 \
    audio.nvrc.tegra:32 \
    audio.r_submix.default:32

# Most of these should have dependencies from elsewhere, and don't need to be here
PRODUCT_PACKAGES += \
    libaacdec:32 \
    libaudioavp:32 \
    libaudioservice:32 \
    libaudioutils:32 \
    libtinyalsa:32 \
    libtinycompress:32 \
    libh264enc:32 \
    libh264msenc:32 \
    libmpeg4enc:32 \
    libnv_parser:32 \
    libnv3gpwriter:32 \
    libnvaacplusenc:32 \
    libnvamrnbcommon:32 \
    libnvamrnbdec:32 \
    libnvamrnbenc:32 \
    libnvamrwbdec:32 \
    libnvamrwbenc:32 \
    libnvvisualizer:32 \
    libnvaudio_memtuils:32 \
    libnvaudio_power:32 \
    libnvaudio_ratecontrol:32 \
    libnvaudioutils:32 \
    libnvaviparserhal:32 \
    libnvavp \
    libnvbasewriter:32 \
    libnvme_msenc:32 \
    libnvmm:32 \
    libnvmmcommon:32 \
    libnvmm_audio:32 \
    libnvmm_aviparser:32 \
    libnvmm_contentpipe:32 \
    libnvmm_msaudio:32 \
    libnvmm_parser:32 \
    libnvmm_utils:32 \
    libnvmm_writer:32 \
    libnvmmlite:32 \
    libnvmmlite_audio:32 \
    libnvmmlite_image:32 \
    libnvmmlite_msaudio:32 \
    libnvmmlite_utils:32 \
    libnvmmlite_video:32 \
    libnvmmtransport:32 \
    libnvoggdec:32 \
    libnvparser:32 \
    libnvtnr:32 \
    libnvtsecmpeg2ts:32 \
    libnvtvmr:32 \
    libnvwavdec:32 \
    libnvwavenc:32 \
    libnvwma:32 \
    libnvwmalsl:32 \
    libnvomx:32 \
    libnvomxadaptor:32 \
    libnvmjolnirutils:32 \
    libnvomxilclient:32 \
    libnvviccrc:32 \
    libstagefrighthw:32 \
    libstagefright_hdcp:32 \
    libtsechdcp:32 \
    libvp8msenc:32 \
    libnvbuf_utils:32 \
    libnveglstream_camconsumer:32 \
    libtegrav4l2:32 \
    libv4l2_nvvidconv:32 \
    libv4l2_nvvideocodec:32

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
PRODUCT_PACKAGES += \
    libvuducrypto \
    libvududrmplugin \
    libstreamplayer \
    libstreamplayerbase \
    libvududrmpluginbase
endif

PRODUCT_PACKAGES += \
    libndkbinderutil \
    libndkbinderutilstub \
    nvtranscode \
    nvtranscodestub \

ifneq ($(BOARD_REMOVES_RESTRICTED_CODEC),true)
PRODUCT_PACKAGES += \
    libnvasfparserhal:32 \
    libnvmm_asfparser:32
endif

## Add 64-bit MM libs
PRODUCT_PACKAGES += \
    libnvtvmr \
    libnvomx \
    libnvmmlite_video \
    libnvmmlite_image \
    libnvmm_parser \
    libnvomxadaptor \
    libnvmjolnirutils
