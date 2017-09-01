# NVIDIA TegraShield factory development system
#
# Copyright (c) 2013-2015 NVIDIA Corporation.  All rights reserved.
#

#====   Add factory ramdisk as an internal product   ====
_factory_product_var_list := \
PRODUCT_FACTORY_RAMDISK_MODULES \
PRODUCT_FACTORY_KERNEL_MODULES \

INTERNAL_PRODUCT := $(call resolve-short-product-name, $(TARGET_PRODUCT))

$(foreach v, $(_factory_product_var_list), $(if $($(v)),\
    $(eval PRODUCTS.$(INTERNAL_PRODUCT).$(v) += $(sort $($(v))))))

TARGET_FACTORY_RAMDISK_OUT := $(PRODUCT_OUT)/factory_ramdisk

ifndef BOARD_KERNEL_BASE
BOARD_KERNEL_BASE:=10000000
endif
#========================================================

ifeq (,$(ONE_SHOT_MAKEFILE))
ifneq ($(TARGET_BUILD_PDK),true)
  TARGET_BUILD_FACTORY=true
endif
ifeq ($(TARGET_BUILD_FACTORY),true)

# PRODUCT_FACTORY_RAMDISK_MODULES consists of "<module_name>:<install_path>[:<install_path>...]" tuples.
# <install_path> is relative to TARGET_FACTORY_RAMDISK_OUT.
# We can have multiple <install_path>s because multiple modules may have the same name.
# For example:
# PRODUCT_FACTORY_RAMDISK_MODULES := \
#     toolbox:system/bin/toolbox adbd:sbin/adbd adb:system/bin/adb
factory_ramdisk_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_RAMDISK_MODULES))
ifneq (,$(factory_ramdisk_modules))

# A module name may end up in multiple modules (so multiple built files)
# with the same name.
# This function selects the module built file based on the install path.
# $(1): the dest install path
# $(2): the module built files
define install-one-factory-ramdisk-module
$(eval _iofrm_suffix := $(suffix $(1))) \
$(if $(_iofrm_suffix), \
    $(eval _iofrm_pattern := %$(_iofrm_suffix)), \
    $(eval _iofrm_pattern := %$(notdir $(1)))) \
$(eval _iofrm_src := $(filter $(_iofrm_pattern),$(2))) \
$(if $(filter 1,$(words $(_iofrm_src))), \
    $(eval _fulldest := $(TARGET_FACTORY_RAMDISK_OUT)/$(1)) \
    $(eval $(call copy-one-file,$(_iofrm_src),$(_fulldest))) \
    $(eval INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES += $(_fulldest)), \
    $(warning Warning: Cannot find built file in "$(2)" for "$(1)") \
    )
endef

#------------------------------------------
# Build kernel modules for factory
FACTORY_KERNEL_MODULE_TARGET :=
factory_kernel_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_KERNEL_MODULES))
ifneq (,$(factory_kernel_modules))

FACTORY_KERNEL_MODULE_TARGET := $(TARGET_FACTORY_RAMDISK_OUT)/kmod

ifeq ($(TARGET_ARCH),arm64)
PRIVATE_KERNEL_TOOLCHAIN := $(CURDIR)/$(TARGET_TOOLS_PREFIX)
else
PRIVATE_KERNEL_TOOLCHAIN := $(ARM_EABI_TOOLCHAIN)/../../../aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
endif

PRIVATE_SRC_PATH := $(CURDIR)/kernel
TARGET_ARCH_KERNEL ?= $(TARGET_ARCH)
PRIVATE_KERNEL_CFLAGS := -mno-android

ifneq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
  ifeq ( , $(2ND_TARGET_GCC_VERSION))
    CROSS32CC=$(ARM_EABI_TOOLCHAIN)/arm-eabi-gcc
  else
    CROSS32CC=$(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-$(2ND_TARGET_GCC_VERSION)/bin/arm-eabi-gcc
  endif
else
    CROSS32CC=$(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.8/bin/arm-eabi-gcc
endif

# Always use absolute path for NV_KERNEL_INTERMEDIATES_DIR
ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
NV_KERNEL_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL
else
NV_KERNEL_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/KERNEL
endif

$(FACTORY_KERNEL_MODULE_TARGET): kmodules
	@echo "Building factory kernel modules"
	$(foreach m, $(factory_kernel_modules), \
		$(eval _fk_m_tuple := $(subst :, ,$(m))) \
		$(eval _fk_m_srcs += $(word 1,$(_fk_m_tuple))) \
		$(eval _fk_m_dests += $(PRODUCT_OUT)/$(word 2,$(_fk_m_tuple))) \
	)
	$(hide) for m in $(_fk_m_srcs) ; do $(kernel-make) M="$$m" ; done
	$(hide) for d in $(_fk_m_dests) ; do mkdir -p $$d; for f in `find $(_fk_m_srcs) -name "*.ko"` ; do cp -v "$$f" $$d ; done ; done

endif
#------------------------------------------

INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES :=
$(foreach m, $(factory_ramdisk_modules), \
    $(eval _fr_m_tuple := $(subst :, ,$(m))) \
    $(eval _fr_m_name := $(word 1,$(_fr_m_tuple))) \
    $(eval _fr_dests := $(wordlist 2,999,$(_fr_m_tuple))) \
    $(eval _fr_m_built := $(filter $(PRODUCT_OUT)/%, $(ALL_MODULES.$(_fr_m_name).BUILT))) \
    $(foreach d,$(_fr_dests),$(call install-one-factory-ramdisk-module,$(d),$(_fr_m_built))) \
    )
endif

# Files may also be installed via PRODUCT_COPY_FILES, PRODUCT_PACKAGES etc.
INTERNAL_FACTORY_RAMDISK_FILES := $(filter $(TARGET_FACTORY_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

ifneq (,$(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES)$(INTERNAL_FACTORY_RAMDISK_FILES))

# -----------------------------------------------------------------
# Build factory default.prop
ifeq ($(BUILD_FACTORY_DEFAULT_PROPERTIES),true)
INSTALLED_FACTORY_DEFAULT_PROP_TARGET := $(TARGET_FACTORY_RAMDISK_OUT)/default.prop
INTERNAL_FACTORY_RAMDISK_FILES += $(INSTALLED_FACTORY_DEFAULT_PROP_TARGET)
FACTORY_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(FACTORY_DEFAULT_PROPERTIES))
FACTORY_DEFAULT_PROPERTIES += \
    $(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES)) \
    $(call collapse-pairs, $(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))

FACTORY_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FACTORY_DEFAULT_PROPERTIES),=)

$(INSTALLED_FACTORY_DEFAULT_PROP_TARGET):
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# FACTORY_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FACTORY_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) echo "#" >> $@; \
	        echo "# BOOTIMAGE_BUILD_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) echo ro.bootimage.build.date=`date`>>$@
	$(hide) echo ro.bootimage.build.date.utc=`date +%s`>>$@
	$(hide) echo ro.bootimage.build.fingerprint="$(BUILD_FINGERPRINT)">>$@
	$(hide) build/tools/post_process_props.py $@
endif #BUILD_FACTORY_DEFAULT_PROPERTIES

# These files are made by magic in build/core/Makefile so we need to explicitly include them
$(eval $(call copy-one-file,$(TARGET_OUT)/build.prop,$(TARGET_FACTORY_RAMDISK_OUT)/system/build.prop))
INTERNAL_FACTORY_RAMDISK_FILES += $(TARGET_FACTORY_RAMDISK_OUT)/system/build.prop


BUILT_FACTORY_RAMDISK_FS := $(PRODUCT_OUT)/factory_ramdisk.gz
BUILT_FACTORY_RAMDISK_TARGET := $(PRODUCT_OUT)/factory_ramdisk.img

INSTALLED_FACTORY_RAMDISK_FS := $(BUILT_FACTORY_RAMDISK_FS)
$(INSTALLED_FACTORY_RAMDISK_FS) : $(FACTORY_KERNEL_MODULE_TARGET) $(MKBOOTFS) \
    $(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES) $(INTERNAL_FACTORY_RAMDISK_FILES) | $(MINIGZIP)
	$(foreach d, $(INTERNAL_FACTORY_RAMDISK_DIRECTORYS), $(shell mkdir -p $(TARGET_FACTORY_RAMDISK_OUT)/$(d)))
	$(call pretty,"Target factory ram disk file system: $@")
	$(hide) $(MKBOOTFS) $(TARGET_FACTORY_RAMDISK_OUT) | $(MINIGZIP) > $@

TARGET_RAMDISK_KERNEL := $(INSTALLED_KERNEL_TARGET)
INSTALLED_FACTORY_RAMDISK_TARGET := $(BUILT_FACTORY_RAMDISK_TARGET)
ifneq (,$(BOARD_KERNEL_CMDLINE_FACTORY_BOOT))
  RAMDISK_CMDLINE := --cmdline "$(BOARD_KERNEL_CMDLINE_FACTORY_BOOT)"
else
  RAMDISK_CMDLINE :=
endif

# make factory_ramdisk.img and sign if need
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER))
$(INSTALLED_FACTORY_RAMDISK_TARGET) : $(MKBOOTIMG) $(TARGET_RAMDISK_KERNEL) $(INSTALLED_FACTORY_RAMDISK_FS) $(BOOT_SIGNER)
	$(call pretty,"Target factory ramdisk img format: $@")
	$(MKBOOTIMG) --kernel $(TARGET_RAMDISK_KERNEL) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS) \
          --base $(BOARD_KERNEL_BASE) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) $(RAMDISK_CMDLINE) --output $@
	$(BOOT_SIGNER) /boot $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $@
else ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT))
$(INSTALLED_FACTORY_RAMDISK_TARGET) : $(MKBOOTIMG) $(TARGET_RAMDISK_KERNEL) $(INSTALLED_FACTORY_RAMDISK_FS) $(VBOOT_SIGNER)
	$(call pretty,"Target factory ramdisk img format: $@")
	$(MKBOOTIMG) --kernel $(TARGET_RAMDISK_KERNEL) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS) \
          --base $(BOARD_KERNEL_BASE) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) $(RAMDISK_CMDLINE) --output $@.unsigned
	$(VBOOT_SIGNER) $(FUTILITY) $@.unsigned $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $@.keyblock $@
else
$(INSTALLED_FACTORY_RAMDISK_TARGET) : $(MKBOOTIMG) $(TARGET_RAMDISK_KERNEL) $(INSTALLED_FACTORY_RAMDISK_FS) $(BOOT_SIGNER)
	$(call pretty,"Target factory ramdisk img format: $@")
	$(MKBOOTIMG) --kernel $(TARGET_RAMDISK_KERNEL) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS) \
          --base $(BOARD_KERNEL_BASE) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) $(RAMDISK_CMDLINE) --output $@
endif

endif #ifneq (,$(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES)$(INTERNAL_FACTORY_RAMDISK_FILES))

endif # TARGET_BUILD_FACTORY
endif # ONE_SHOT_MAKEFILE
