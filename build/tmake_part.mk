################################### tell Emacs this is a -*- makefile-gmake -*-
#
# Copyright (c) 2014-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################
#
# This makefile fragment is used to execute a tmake part umbrella and
# add the resulting build artifacts as prebuilts in the Android build
#
###############################################################################
#
# Sanity checks for mandatory configuration variables
#
# LOCAL_NVIDIA_TMAKE_PART_NAME - name of the tmake part umbrella
#
LOCAL_NVIDIA_TMAKE_PART_NAME := $(strip $(LOCAL_NVIDIA_TMAKE_PART_NAME))
ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),)
  $(error $(LOCAL_PATH): LOCAL_NVIDIA_TMAKE_PART_NAME is not defined)
endif
#
# LOCAL_NVIDIA_TMAKE_PART_ARTIFACT - path to build artifact for LOCAL_MODULE
#
LOCAL_NVIDIA_TMAKE_PART_ARTIFACT := $(strip $(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT))
ifeq ($(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT),)
  $(error $(LOCAL_PATH): LOCAL_NVIDIA_TMAKE_PART_ARTIFACT is not defined)
endif
#
# Map REFERENCE_DEVICE to a reference board supported by tmake
#
#   <REFERENCE_DEVICE value>=<tmake board name>
#
_tmake_config_devices := \
	ardbeg=ardbeg \
	loki=loki \
	p1859=p1859ref \
	p1889=p1889ref \
	shieldtablet=ardbeg \
	greenarrow=ardbeg \
	t132=t132ref \
	t186=t186ref \
	t210=t210ref \
	vcm31t210=t210ref \
	t210_upstream=t210ref
_tmake_config_device  := $(word 2,$(subst =, ,$(filter $(REFERENCE_DEVICE)=%, $(_tmake_config_devices))))
ifndef _tmake_config_device
  $(error $(LOCAL_PATH): reference device "$(REFERENCE_DEVICE)" is not supported)
endif


###############################################################################
#
# Translate from Android to tmake SW Build system
#
ifneq ($(filter tf tlk y,$(SECURE_OS_BUILD)),)
_tmake_config_secureos := 1
else
_tmake_config_secureos := 0
endif
ifneq ($(SHOW_COMMANDS),)
_tmake_config_verbose  := 1
else
_tmake_config_verbose  := 0
endif
ifeq ($(HOST_BUILD_TYPE),debug)
_tmake_host_debug      := 1
else
_tmake_host_debug      := 0
endif
ifeq ($(TARGET_BUILD_TYPE),debug)
_tmake_target_debug    := 1
else
_tmake_target_debug    := 0
endif


###############################################################################
#
# tmake part umbrellas build multiple different components in one go. Thus they
# don't fit into the standard Android directory structure under $(OUT_DIR).
#
# This is the root directory to which an umbrella specific part will be added.
#
_tmake_intermediates := $(OUT_DIR)/tmake/part/$(LOCAL_NVIDIA_TMAKE_PART_NAME)


###############################################################################
#
# Umbrella specific configuration
#
ifneq ($(filter bootloader static.bootloader,$(LOCAL_NVIDIA_TMAKE_PART_NAME)),)
# bootloader is OS, security & board specific
_tmake_config_extra  := \
		NV_BUILD_CONFIGURATION_IS_SECURE_OS=$(_tmake_config_secureos) \
		NV_BUILD_SYSTEM_TYPE=android \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_target_debug)
_tmake_part_umbrella := bootloader/nvbootloader/app/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),cboot)
# cboot is OS and board specific (= board determines chip family)
_tmake_config_extra  := \
		NV_BUILD_SYSTEM_TYPE=android \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_target_debug)
_tmake_part_umbrella := bootloader/cboot/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifneq ($(filter nvtboot static.nvtboot,$(LOCAL_NVIDIA_TMAKE_PART_NAME)),)
# nvtboot is security & board specific (= board determines chip family)
_tmake_config_extra  := \
		NV_BUILD_CONFIGURATION_IS_SECURE_OS=$(_tmake_config_secureos) \
		NV_BUILD_SYSTEM_TYPE=android \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_target_debug)
_tmake_part_umbrella := bootloader/nvtboot/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),warmboot)
# warmboot is security specific
_tmake_config_extra  := \
		NV_BUILD_CONFIGURATION_IS_SECURE_OS=$(_tmake_config_secureos) \
		NV_TARGET_BOARD=$(_tmake_config_device)
# Android does not support building secure & non-secure in same work tree
_tmake_intermediates := $(_tmake_intermediates)_$(_tmake_config_device)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_target_debug)
_tmake_part_umbrella := warmboot/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),nvflash)
# host tool code is agnostic to target configuration
_tmake_config_extra  :=
# NOTE: build type for target bits is also controlled by HOST_BUILD_TYPE
_tmake_intermediates := $(_tmake_intermediates)_$(HOST_BUILD_TYPE)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_host_debug)
_tmake_part_umbrella := bootloader/nvbootloader/nvflash/app/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),nvsecuretool)
# host tool code is agnostic to target configuration
_tmake_config_extra  :=
# NOTE: build type for target bits is also controlled by HOST_BUILD_TYPE
_tmake_intermediates := $(_tmake_intermediates)_$(HOST_BUILD_TYPE)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_host_debug)
_tmake_part_umbrella := bootloader/nvbootloader/nvsecuretool/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),tegraflash)
# host tool code is agnostic to target configuration
_tmake_config_extra  :=
# NOTE: build type for target bits is also controlled by HOST_BUILD_TYPE
_tmake_intermediates := $(_tmake_intermediates)_$(HOST_BUILD_TYPE)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_host_debug)
_tmake_part_umbrella := bootloader/cboot/tegraflash/build/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else ifeq ($(LOCAL_NVIDIA_TMAKE_PART_NAME),static.host)
# host tool code is agnostic to target configuration
_tmake_config_extra  :=
# NOTE: build type for target bits is also controlled by HOST_BUILD_TYPE
_tmake_intermediates := $(_tmake_intermediates)_$(HOST_BUILD_TYPE)_$(TARGET_BUILD_TYPE)
_tmake_config_debug  := $(_tmake_host_debug)
_tmake_part_umbrella := tmake/umbrella/parts/Makefile.$(LOCAL_NVIDIA_TMAKE_PART_NAME)

else
  $(error $(LOCAL_PATH): tmake part umbrella "$(LOCAL_NVIDIA_TMAKE_PART_NAME)" is not supported)
endif


###############################################################################
#
# Additional configuration for customer build mode
#
# NOTE: for historical reasons ODM sources are visible at a different
#       location in customer builds than in internal builds.
#
ifeq ($(NV_BUILD_TMAKE_CUSTOMER_BUILD),1)
_tmake_config_extra  += \
	NV_CUSTOMER_BUILD=1 \
	NV_INTERFACE_BOOTLOADER_ODM=$(TEGRA_TOP)/odm/Makefile.odm.tmk \
	NV_RELDIR=$(TEGRA_TOP)/prebuilt/$(REFERENCE_DEVICE)/tmake
_tmake_sub_directory := customer
else
_tmake_sub_directory := nvidia
endif


###############################################################################
#
# Dependency between tmake build and Android module
#
_tmake_part_stamp := $(_tmake_intermediates)/tmake.stamp


###############################################################################
#
# Execute tmake part umbrella
#
# This part can only be included once per tmake part umbrella.
#
ifndef _tmake_part_$(LOCAL_NVIDIA_TMAKE_PART_NAME)_was_included
_tmake_part_$(LOCAL_NVIDIA_TMAKE_PART_NAME)_was_included := 1

# make sure tmake build is entered every time
.PHONY: $(_tmake_part_stamp)

$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_DEBUG   := $(_tmake_config_debug)
$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_EXTRA   := $(_tmake_config_extra)
$(_tmake_part_stamp): PRIVATE_TMAKE_CONFIG_VERBOSE := $(_tmake_config_verbose)
$(_tmake_part_stamp): PRIVATE_TMAKE_INTERMEDIATES  := $(if $(filter-out /%,$(_tmake_intermediates)),$(ANDROID_BUILD_TOP)/)$(_tmake_intermediates)
$(_tmake_part_stamp): PRIVATE_TMAKE_PART_NAME      := $(LOCAL_NVIDIA_TMAKE_PART_NAME)
$(_tmake_part_stamp): PRIVATE_TMAKE_PART_UMBRELLA  := $(_tmake_part_umbrella)

$(_tmake_intermediates):
	$(hide)mkdir -p $@

$(_tmake_part_stamp): $(TEGRA_TOP)/$(_tmake_part_umbrella) | $(_tmake_intermediates)
	@echo Executing tmake "$(PRIVATE_TMAKE_PART_NAME)" part umbrella build
	$(hide)rm -f $@
	$(hide)$(MAKE) -C $(TEGRA_TOP) -f $(PRIVATE_TMAKE_PART_UMBRELLA) \
		NV_ANDROID_TOP=$(ANDROID_BUILD_TOP) \
		NV_BUILD_CONFIGURATION_IS_DEBUG=$(PRIVATE_TMAKE_CONFIG_DEBUG) \
		NV_BUILD_CONFIGURATION_IS_VERBOSE=$(PRIVATE_TMAKE_CONFIG_VERBOSE) \
		$(PRIVATE_TMAKE_CONFIG_EXTRA) \
		NV_OUTDIR=$(PRIVATE_TMAKE_INTERMEDIATES)
	$(hide)touch $@
endif


###############################################################################
#
# The actual Android module: map tmake build artifact to Android prebuilt
#
LOCAL_PREBUILT_MODULE_FILE := $(_tmake_intermediates)/$(_tmake_sub_directory)/$(LOCAL_NVIDIA_TMAKE_PART_ARTIFACT)

$(LOCAL_PREBUILT_MODULE_FILE): $(_tmake_part_stamp)

ifneq ($(filter EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
# By using binary.mk we can use LOCAL_STATIC_LIBRARIES & friends
include $(NVIDIA_BASE)
include $(BUILD_SYSTEM)/binary.mk
include $(NVIDIA_POST)

$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE) $(LOCAL_MODULE_MAKEFILE) $(all_libraries) | $(ACP)
	$(transform-prebuilt-to-target)

else
include $(NVIDIA_PREBUILT)
endif


###############################################################################
#
# variable cleanup
#
_tmake_config_debug    :=
_tmake_config_device   :=
_tmake_config_devices  :=
_tmake_config_extra    :=
_tmake_config_secureos :=
_tmake_config_verbose  :=
_tmake_host_debug      :=
_tmake_intermediates   :=
_tmake_part_stamp      :=
_tmake_part_umbrella   :=
_tmake_sub_directory   :=
_tmake_target_debug    :=


# Local Variables:
# indent-tabs-mode: t
# tab-width: 8
# End:
# vi: set tabstop=8 noexpandtab:
