NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifeq ($(LOCAL_MODULE_CLASS),)
$(error $(NVIDIA_MAKEFILE): empty LOCAL_MODULE_CLASS is not allowed))
endif

ifeq ($(filter $(LOCAL_MODULE_CLASS),APPS ETC STATIC_LIBRARIES),)
  ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
    #
    # Stubbed implementation
    #
    # For now we allow replacing shared libraries by empty stubs.
    # We'll need to revisit if some of our build modules export prebuilt shared
    # libraries for other modules to link against at build time. For instance we
    # could add an option to always install the real binary for such shared
    # libraries.
    #
    $(nvidia_build_modularization_stub_filter_locals)

    # Generate empty stub prebuilt
    GEN := $(local-generated-sources-dir)/$(LOCAL_MODULE)

    $(GEN): PRIVATE_CUSTOM_TOOL = touch $@
    $(GEN):
		$(transform-generated-source)

    LOCAL_PREBUILT_MODULE_FILE := $(GEN)
  endif
endif

include $(BUILD_SYSTEM)/multilib.mk

ifdef LOCAL_IS_HOST_MODULE
ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
#ifneq ($(LOCAL_MODULE_CLASS),EXECUTABLES)
ifneq ($(findstring $(LOCAL_MODULE_CLASS),STATIC_LIBRARIES SHARED_LIBRARIES),)
    ifeq ($(HOST_PREFER_32_BIT),true)
        LOCAL_MULTILIB := 32
    else
    # By default we only build host module for the first arch.
        LOCAL_MULTILIB := first
    endif # HOST_PREFER_32_BIT
endif # EXECUTABLES STATIC_LIBRARIES SHARED_LIBRARIES
endif
endif
endif

include $(NVIDIA_BASE)

ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
ifneq ($(filter %.py,$(LOCAL_SRC_FILES)),)
LOCAL_STRIP_MODULE := false
endif
endif

include $(BUILD_PREBUILT)
include $(NVIDIA_POST)
