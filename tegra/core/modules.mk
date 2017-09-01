# DO NOT add conditionals to this makefile of the form
#
#    ifeq ($(TARGET_TEGRA_VERSION),<latest SOC>)
#        <stuff for latest SOC>
#    endif
#
# Such conditionals break forward compatibility with future SOCs.
# If you must add conditionals to this makefile, use the form
#
#    ifneq ($(filter <list of older SOCs>,$(TARGET_TEGRA_VERSION)),)
#       <stuff for old SOCs>
#    else
#       <stuff for new SOCs>
#    endif

nv_modules := \
    com.nvidia.nvstereoutils \
    DidimCalibration \
    fuse_bypass.txt \
    gps.$(TARGET_BOARD_PLATFORM) \
    gps.mtk \
    hdcp_test \
    hdcp1x.srm \
    hdcp2x.srm \
    hdcp2xtest.srm \
    hosts \
    init.hdcp \
    init.tlk \
    libhybrid \
    libmd5 \
    libmnlp_mt3332 \
    libnvapputil \
    libnvboothost \
    libnvfxmath \
    libnvimageio \
    libnvos \
    libnvrm \
    libnvrm_graphics \
    libnvrm_impl \
    libnvrm_limits \
    libnvrm_secure \
    libnvsystemuiext_jni \
    librs_jni \
    mnld \
    mnl.prop \
    MockNVCP \
    nfc.$(TARGET_BOARD_PLATFORM) \
    pbc \
    pbc2 \
    lbh_images \
    QuadDSecurityService \
    sensors.default.api_v1.3.mpl520.nvs \
    sensors.default.api_v1.3.mpl530.nvs \
    sensors.default.api_v1.4.mpl520.nvs \
    sensors.default.api_v1.4.mpl530.nvs \
    sensors.p1889.p1889.nvs \
    libsensors.fusion.mpl520.nvs \
    libsensors.fusion.mpl530.nvs \
    libsensors.fusion.p1889.nvs \
    libsensors.hal-drivers.nvs \
    libsensors.hal.nvs \
    libsensors.prefusion.mpl520.nvs \
    libsensors.prefusion.mpl530.nvs \
    libsensors.prefusion.p1889.nvs \
    inv_self_test \
    libmllite \
    libmplmpu \
    tegrastats \
    ussrd \
    cvc \
    trace-cmd \
    powercap \
    PowerShark \
    libnvopt_dvm \
    NvBenchmarkBlocker \
    libnvcpl \
    com.nvidia.NvCPLSvc.api
#    TegraOTA \
# disabled mjolnir components
#    libgrid \
#    libgrid_jrtp \
#    nvpgcservice \
#    libremoteinput \
#    libnvthreads \
#    libnvrtpaudio \
#    libadaptordecoder \
#    libadaptordecoderjni \
# nvcpud
#    libnvcpud \
#    nvcpud \

ifneq ($(NV_AUTOMOTIVE_BUILD),true)
nv_modules += \
    NvCPLSvc \
    NvCPLUpdater
endif

ifeq ($(TARGET_USE_NCT),true)
nv_modules += \
    libnvnct
endif

ifeq ($(SECURE_OS_BUILD),tlk)
nv_modules += \
    tos \
    tlk \
    tlk_daemon \
    keystore.tegra \
    eks2_client
endif

include $(CLEAR_VARS)

LOCAL_MODULE := nvidia_tegra_proprietary_src_modules
LOCAL_REQUIRED_MODULES := $(nv_modules)
LOCAL_REQUIRED_MODULES += $(ALL_NVIDIA_TESTS)
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE := nvidia-google-tests
include $(BUILD_PHONY_PACKAGE)
