#
# Copyright (c) 2016, Google Inc.  All rights reserved.
# Copyright (c) 2013-2016, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target static library
#
include $(NVIDIA_BASE)

LOCAL_SYSTEM_SHARED_LIBRARIES :=
LOCAL_UNINSTALLABLE_MODULE    := true

ifeq ($(LOCAL_NDK_STL_VARIANT)$(LOCAL_SDK_VERSION)$(LOCAL_CXX_STL), default)
# Historically CUDA static libraries have been building against gnustl_static
# from PDK. The reason seems to be about stl compatibility with cuda toolkit.
#
# This needs to be updated based together with cuda toolkit version.

LOCAL_SDK_VERSION := 18
LOCAL_NDK_STL_VARIANT := gnustl_static
endif

LOCAL_CLANG := false
LOCAL_NO_CRT := true
LOCAL_SYSTEM_SHARED_LIBRARIES :=

cuda_sources := $(filter %.cu,$(LOCAL_SRC_FILES))

my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architecturess
my_module_multilib := both
endif

ifeq ($(my_module_multilib),both)
ifneq ($(LOCAL_MODULE_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(warning $(LOCAL_MODULE): LOCAL_MODULE_PATH for shared libraries is unsupported in multiarch builds, use LOCAL_MODULE_RELATIVE_PATH instead)
endif
endif

ifneq ($(LOCAL_UNSTRIPPED_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(warning $(LOCAL_MODULE): LOCAL_UNSTRIPPED_PATH for shared libraries is unsupported in multiarch builds)
endif
endif
endif # my_module_multilib == both


LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(NVIDIA_BUILD_ROOT)/cuda_static_library_internal.mk
endif

ifdef TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
# Build for TARGET_2ND_ARCH
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_MODULE_STEM :=
LOCAL_BUILT_MODULE_STEM :=
LOCAL_INSTALLED_MODULE_STEM :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(NVIDIA_BUILD_ROOT)/cuda_static_library_internal.mk

endif

LOCAL_2ND_ARCH_VAR_PREFIX :=

endif # TARGET_2ND_ARCH

my_module_arch_supported :=

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)
include $(NVIDIA_POST)

