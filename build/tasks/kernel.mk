#
# Linux kernel and loadable kernel modules
#

# We don't need kernel for standalone bootloader build
ifeq ($(BUILD_STANDALONE_BOOTLOADER), 1)
TARGET_NO_KERNEL := true
endif

# record defconfig name for build modularization
$(PRODUCT_OUT)/kernel-configuration-name.txt:
	$(hide) echo $(TARGET_KERNEL_CONFIG) >$@

# record SIM DTS name for build modularization
$(PRODUCT_OUT)/kernel-simdts-name.txt:
	$(hide) echo $(SIM_KERNEL_DT_NAME).dts >$@

ifneq ($(filter kernel,$(BUILD_BRAIN_MODULAR_COMPONENTS)),)
# Provide dummy targets for system builder when modular kernel is enabled
.PHONY: build_kernel_tests kernel-tests

# Provide a dummy kernel image
$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-simdts-name.txt
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

else ifdef BUILD_BRAIN_MODULAR_NAME
# Nothing to do in user space module builders.
# The kernel module builder doesn't use the Android build system, so it doesn't
# need to be handled here.
else ifneq ($(TARGET_NO_KERNEL),true)

ifneq ($(NV_SKIP_KERNEL_BUILD),1)

ifneq ($(TOP),.)
$(error Kernel build assumes TOP == . i.e Android build has been started from TOP/Makefile )
endif

# Android build is started from the $TOP/Makefile, therefore $(CURDIR)
# gives the absolute path to the TOP.
KERNEL_PATH ?= $(CURDIR)/kernel

#kernel_version := $(strip $(shell head $(KERNEL_PATH)/Makefile | \
#	grep "SUBLEVEL =" | cut -d= -f2))

# Special handling for ARM64 kernel (diff arch/ and built-in bootloader)
TARGET_ARCH_KERNEL ?= $(TARGET_ARCH)

# Always use absolute path for NV_KERNEL_INTERMEDIATES_DIR
ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
NV_KERNEL_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL
else
NV_KERNEL_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/KERNEL
endif

dotconfig := $(NV_KERNEL_INTERMEDIATES_DIR)/.config
ifeq ($(TARGET_ARCH_KERNEL),arm64)
ifeq ($(BOARD_SUPPORT_KERNEL_COMPRESS),gzip)
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage
else
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/Image
endif
else
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage
endif

ifeq ($(TARGET_TEGRA_VERSION),t30)
    TARGET_KERNEL_CONFIG ?= tegra3_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t114)
    TARGET_KERNEL_CONFIG ?= tegra11_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t148)
    TARGET_KERNEL_CONFIG ?= tegra14_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t124)
    TARGET_KERNEL_CONFIG ?= tegra12_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t132)
    TARGET_KERNEL_CONFIG ?= tegra13_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t210)
    TARGET_KERNEL_CONFIG ?= tegra21_android_defconfig
else ifeq ($(TARGET_TEGRA_VERSION),t186)
    TARGET_KERNEL_CONFIG ?= tegra18_android_defconfig
endif

ifeq ($(TARGET_TEGRA_VERSION),t186)
    DEFCONFIG_PATH ?= $(CURDIR)/kernel-t18x/arch/$(TARGET_ARCH_KERNEL)/configs
else
    DEFCONFIG_PATH ?= $(KERNEL_PATH)/arch/$(TARGET_ARCH_KERNEL)/configs
endif

ifeq ($(wildcard $(DEFCONFIG_PATH)/$(TARGET_KERNEL_CONFIG)),)
    $(error Could not find kernel defconfig for board)
endif


# Always use absolute path for NV_KERNEL_MODULES_TARGET_DIR and
# NV_KERNEL_BIN_TARGET_DIR
ifneq ($(filter /%, $(TARGET_OUT)),)
NV_KERNEL_MODULES_TARGET_DIR := $(TARGET_OUT)/lib/modules
NV_KERNEL_BIN_TARGET_DIR     := $(TARGET_OUT)/bin
else
NV_KERNEL_MODULES_TARGET_DIR := $(CURDIR)/$(TARGET_OUT)/lib/modules
NV_KERNEL_BIN_TARGET_DIR     := $(CURDIR)/$(TARGET_OUT)/bin
endif

ifeq ($(BOARD_WLAN_DEVICE),wl12xx_mac80211)
    NV_COMPAT_KERNEL_DIR := $(CURDIR)/3rdparty/ti/compat-wireless
    NV_COMPAT_KERNEL_MODULES_TARGET_DIR := $(NV_KERNEL_MODULES_TARGET_DIR)/compat
endif

ifeq ($(BOARD_WLAN_DEVICE),wl18xx_mac80211)
    NV_COMPAT_KERNEL_DIR := $(CURDIR)/3rdparty/ti/compat-wireless/compat-wireless-wl8
    NV_COMPAT_KERNEL_MODULES_TARGET_DIR := $(NV_KERNEL_MODULES_TARGET_DIR)/compat
endif

KERNEL_DEFCONFIG_PATH := $(DEFCONFIG_PATH)/$(TARGET_KERNEL_CONFIG)

define dts-files-under
$(patsubst ./%,%,$(shell find $(1) -name "$(2)-*.dts"))
endef

define word-dash
$(word $(1),$(subst -,$(space),$(2)))
endef

# The target must provide a name for the DT file (sources located in arch/arm/boot/dts/*)
ifeq ($(TARGET_KERNEL_DT_NAME),)
    $(error Must provide a DT file name in TARGET_KERNEL_DT_NAME -- <kernel>/arch/arm/boot/dts/*)
else
    KERNEL_DTS_PATH := $(call dts-files-under,$(KERNEL_PATH)/arch/$(TARGET_ARCH_KERNEL)/boot/dts,$(call word-dash,1,$(TARGET_KERNEL_DT_NAME)))
    KERNEL_DT_NAME := $(subst .dts,,$(notdir $(KERNEL_DTS_PATH)))
    KERNEL_DT_NAME_DTB := $(subst .dts,.dtb,$(notdir $(KERNEL_DTS_PATH)))
    BUILT_KERNEL_DTB := $(addprefix $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/dts/,$(addsuffix .dtb,$(KERNEL_DT_NAME)))
    TARGET_BUILT_KERNEL_DTB := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/dts/$(TARGET_KERNEL_DT_NAME).dtb
    INSTALLED_DTB_TARGET := $(addprefix $(OUT)/,$(addsuffix .dtb, $(KERNEL_DT_NAME)))
    DTS_PATH_EXIST := $(foreach dts_file,$(KERNEL_DTS_PATH),$(if $(wildcard $(dts_file)),,$(error DTS file not found -- $(dts_file))))
endif

define newline


endef

KERNEL_EXTRA_ARGS=
OS=$(shell uname)
ifeq ($(OS),Darwin)
  # check prerequisites
  ifeq ($(GNU_COREUTILS),)
    $(error GNU_COREUTILS is not set)
  endif
  ifeq ($(wildcard $(GNU_COREUTILS)/stat),)
    $(error $(GNU_COREUTILS)/stat not found. Please install GNU coreutils.)
  endif

  # add GNU stat to the path
  KERNEL_EXTRA_ENV=env PATH=$(GNU_COREUTILS):$(PATH)
  # bring in our elf.h
  KERNEL_EXTRA_ARGS=HOST_EXTRACFLAGS=-I$(TOP)/../vendor/nvidia/tegra/core-private/include\ -DKBUILD_NO_NLS
  HOSTTYPE=darwin-x86
endif

ifeq ($(OS),Linux)
  KERNEL_EXTRA_ENV=
  HOSTTYPE=linux-x86
endif

ifneq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
  ifeq ( , $(2ND_TARGET_GCC_VERSION))
    CROSS32CC=$(ARM_EABI_TOOLCHAIN)/arm-eabi-gcc
  else
    CROSS32CC=$(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-$(2ND_TARGET_GCC_VERSION)/bin/arm-eabi-gcc
  endif
else
    CROSS32CC=$(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.8/bin/arm-eabi-gcc
endif

# We should rather use CROSS_COMPILE=$(PRIVATE_TOPDIR)/$(TARGET_TOOLS_PREFIX).
# Absolute paths used in all path variables.
# ALWAYS prefix these macros with "+" to correctly enable parallel building!
define kernel-make
$(KERNEL_EXTRA_ENV) $(MAKE) -C $(PRIVATE_SRC_PATH) \
    ARCH=$(TARGET_ARCH_KERNEL) \
    CROSS_COMPILE=$(PRIVATE_KERNEL_TOOLCHAIN) KCFLAGS=$(PRIVATE_KERNEL_CFLAGS) \
    CROSS32CC=$(CROSS32CC) \
    O=$(NV_KERNEL_INTERMEDIATES_DIR) $(KERNEL_EXTRA_ARGS) \
    $(if $(SHOW_COMMANDS),V=1)
endef

ifneq ( , $(findstring $(BOARD_WLAN_DEVICE), wl12xx_mac80211 wl18xx_mac80211))
define compat-kernel-make
$(KERNEL_EXTRA_ENV) $(MAKE) -C $(NV_COMPAT_KERNEL_DIR) \
    ARCH=$(TARGET_ARCH_KERNEL) \
    CROSS_COMPILE=$(PRIVATE_KERNEL_TOOLCHAIN) KCFLAGS=$(PRIVATE_KERNEL_CFLAGS) \
    KLIB=$(NV_KERNEL_INTERMEDIATES_DIR) \
    KLIB_BUILD=$(NV_KERNEL_INTERMEDIATES_DIR) \
    $(if $(SHOW_COMMANDS),V=1)
endef
endif

# forces re-execution to check for config changes
.PHONY: $(dotconfig)
$(dotconfig): $(KERNEL_DEFCONFIG_PATH) | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel config " $(TARGET_KERNEL_CONFIG)
	+$(hide) $(kernel-make) DEFCONFIG_PATH=$(DEFCONFIG_PATH) $(TARGET_KERNEL_CONFIG)
ifeq ($(SECURE_OS_BUILD),tlk)
	@echo "TLK SecureOS enabled kernel"
	$(hide) $(KERNEL_PATH)/scripts/config --file $@ \
	--enable TRUSTED_LITTLE_KERNEL \
	--enable TEGRA_USE_SECURE_KERNEL \
	--enable OTE_ENABLE_LOGGER
endif
ifeq ($(NVIDIA_KERNEL_COVERAGE_ENABLED),1)
	@echo "Explicitly enabling coverage support in kernel config on user request"
	$(hide) $(KERNEL_PATH)/scripts/config --file $@ \
		--enable DEBUG_FS \
		--enable GCOV_KERNEL \
		--enable GCOV_TOOLCHAIN_IS_ANDROID \
		--disable GCOV_PROFILE_ALL
endif
ifeq ($(NV_GENERIC_SOC),1)
	@echo "Generic SoC kernel"
	$(hide) $(KERNEL_PATH)/scripts/config --file $@ \
		--disable TEGRA_NVMAP \
		--disable TEGRA_GK20A
endif
ifeq ($(NV_AUTOMOTIVE_BUILD),true)
ifneq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
ifeq ($(REFERENCE_DEVICE),p1859)
	@echo "Explicitly disabling kernel module for automotive early camera"
	$(hide) $(KERNEL_PATH)/scripts/config --file $@ \
		--enable PCI_TEGRA \
		--enable SATA_AHCI_TEGRA \
		--enable SND_SOC_TEGRA_VCM30T124_ALT \
		--enable USB_XHCI_HCD \
		--enable USB_EHCI_HCD \
		--enable RTC_DRV_MAX77663 \
		--enable DYNAMIC_DEBUG
endif
endif
endif


ifeq ($(TARGET_BUILD_TYPE),release)
ifeq ($(TARGET_BUILD_VARIANT),user)
	@echo "Enabling Dynamic Serial Control and disable DEVMEM or user-release variant"
	$(hide) $(KERNEL_PATH)/scripts/config --file $@ --enable CONTROL_CONSOLE_WRITE --disable DEVMEM
endif
endif

ifeq ($(TARGET_ARCH_KERNEL),arm64)
    BOOT_WRAPPER_DIR := $(TOP)/kernel-build/boot-wrapper-aarch64
    BOOT_WRAPPER_FDT_SRC := $(KERNEL_PATH)/arch/$(TARGET_ARCH_KERNEL)/boot/dts/$(SIM_KERNEL_DT_NAME).dts
    BOOT_WRAPPER_CMD := $(MAKE) -C $(BOOT_WRAPPER_DIR) FDT_SRC=$(BOOT_WRAPPER_FDT_SRC);
else
    BOOT_WRAPPER_CMD :=
endif

# core-private isn't present in cust builds, so we can't use files from there.
# Turn off the boot wrapper stuff for cust builds.
ifneq ($(wildcard vendor/nvidia/tegra/core-private),vendor/nvidia/tegra/core-private)
    BOOT_WRAPPER_CMD :=
endif

# TODO: figure out a way of not forcing kernel & module builds.
$(TARGET_BUILT_KERNEL_DTB): $(dotconfig) FORCE
	$(info ==============Kernel DTS/DTB================)
	$(info KERNEL_DT_NAME_DTB = $(KERNEL_DT_NAME_DTB))
	$(info KERNEL_DTS_PATH = $(notdir $(KERNEL_DTS_PATH)))
	$(info BUILT_KERNEL_DTB = $(notdir $(BUILT_KERNEL_DTB)))
	$(info INSTALLED_DTB_TARGET = $(notdir $(INSTALLED_DTB_TARGET)))
	$(info ============================================)
	@echo "Device tree build" $(KERNEL_DT_NAME_DTB)
	+$(hide) $(kernel-make) $(KERNEL_DT_NAME_DTB)

$(BUILT_KERNEL_TARGET): $(dotconfig) $(TARGET_BUILT_KERNEL_DTB) FORCE | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel build"
	+$(hide) $(kernel-make) zImage

kmodules-build_only: $(BUILT_KERNEL_TARGET) FORCE | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel modules build"
	+$(hide) $(kernel-make) modules
ifneq ( , $(findstring $(BOARD_WLAN_DEVICE), wl12xx_mac80211 wl18xx_mac80211))
	+$(hide) $(compat-kernel-make)
endif

# This will add all kernel modules we build for inclusion the system
# image - no blessing takes place.
kmodules: kmodules-build_only FORCE | $(NV_KERNEL_MODULES_TARGET_DIR) $(NV_COMPAT_KERNEL_MODULES_TARGET_DIR)
	@echo "Kernel modules install"
	for f in `find $(NV_KERNEL_INTERMEDIATES_DIR) -name "*.ko"` ; do cp -v "$$f" $(NV_KERNEL_MODULES_TARGET_DIR) ; done
ifneq ( , $(findstring $(BOARD_WLAN_DEVICE), wl12xx_mac80211 wl18xx_mac80211))
	for f in `find $(NV_COMPAT_KERNEL_DIR) -name "*.ko"` ; do cp -v "$$f" $(NV_COMPAT_KERNEL_MODULES_TARGET_DIR) ; done
endif

# At this stage, BUILT_SYSTEMIMAGE in $TOP/build/core/Makefile has not
# yet been defined, so we cannot rely on it.
_systemimage_intermediates_kmodules := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE_KMODULES := $(_systemimage_intermediates_kmodules)/system.img
NV_INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img

# When kernel tests are built, we also want to update the system
# image, but in general case we do not want to build kernel tests
# always.
ifneq ($(findstring kernel-tests,$(MAKECMDGOALS)),)
kernel-tests: build_kernel_tests $(NV_INSTALLED_SYSTEMIMAGE) FORCE

# In order to prevent kernel-tests rule from matching pattern rule
# kernel-%
kernel-tests:
	@echo "Kernel space tests built and system image updated!"

# For parallel builds. Systemimage can only be built after kernel
# tests have been built.
$(BUILT_SYSTEMIMAGE_KMODULES): build_kernel_tests
endif

build_kernel_tests: kmodules FORCE | $(NV_KERNEL_MODULES_TARGET_DIR) $(NV_KERNEL_BIN_TARGET_DIR) build_tegrawatch
	@echo "Kernel space tests build"
	@echo "Tests at $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests"
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests
	for f in `find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests -name "*.ko"` ; do cp -v "$$f" $(NV_KERNEL_MODULES_TARGET_DIR) ; done
	for f in `find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests -name "*.sh"` ; do cp -v "$$f" $(NV_KERNEL_BIN_TARGET_DIR) ; done
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests clean
	find $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests -name "modules.order" -print0 | xargs -0 rm -rf

build_tegrawatch: kmodules FORCE | $(NV_KERNEL_MODULES_TARGET_DIR) $(NV_KERNEL_BIN_TARGET_DIR)
	@echo "Build kernel space build_tegrawatch start"
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/kernel-utils/tegrawatch/tegrawatch/ modules
	cp $(PRIVATE_TOPDIR)/vendor/nvidia/tegra/kernel-utils/tegrawatch/tegrawatch/tegrawatch_mod.ko $(NV_KERNEL_MODULES_TARGET_DIR)
	+$(hide) $(kernel-make) M=$(PRIVATE_TOPDIR)/vendor/nvidia/tegra/kernel-utils/tegrawatch/tegrawatch/ clean
	@echo "Build kernel space build_tegrawatch done"

# Unless we hardcode the list of kernel modules, we cannot create
# a proper dependency from systemimage to the kernel modules.
# If we decide to hardcode later on, BUILD_PREBUILT (or maybe
# PRODUCT_COPY_FILES) can be used for including the modules in the image.
# For now, let's rely on an explicit dependency.
$(BUILT_SYSTEMIMAGE_KMODULES): kmodules

# Following dependency is already defined in $TOP/build/core/Makefile,
# but for the sake of clarity let's re-state it here. This dependency
# causes following dependencies to be indirectly defined:
#   $(NV_INSTALLED_SYSTEMIMAGE): kmodules $(BUILT_KERNEL_TARGET)
# which will prevent too early creation of systemimage.
$(NV_INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE_KMODULES)

# $(INSTALLED_KERNEL_TARGET) is defined in
# $(TOP)/build/target/board/Android.mk
$(INSTALLED_DTB_TARGET): $(TARGET_BUILT_KERNEL_DTB) | $(ACP)
	@echo "Copying DTB file" $(notdir $@)
	@mkdir -p $(dir $@)
	+$(hide) $(ACP) -fp $(addprefix $(dir $<),$(@F)) $@

ifeq ($(BOARD_SUPPORT_KERNEL_COMPRESS),lz4)
# replace kernel image with lz4 compressed kernel image
NVIDIA_KBUILD_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage.lz4
$(NVIDIA_KBUILD_TARGET): $(BUILT_KERNEL_TARGET) | $(NVIDIA_LZ4C)
	@echo "NVIDIA_LZ4C make $@"
	$(hide)$(NVIDIA_LZ4C) -c1 -l -f $< $@
else
# default kernel
NVIDIA_KBUILD_TARGET := $(BUILT_KERNEL_TARGET)
endif

$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-configuration-name.txt
$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-simdts-name.txt
$(INSTALLED_KERNEL_TARGET): $(NVIDIA_KBUILD_TARGET) $(TARGET_BUILT_KERNEL_DTB) $(INSTALLED_DTB_TARGET) FORCE | $(ACP)
	$(copy-file-to-target)

# Kernel build also includes some drivers as kernel modules which are
# packaged inside system image. Therefore, for incremental builds,
# dependency from kernel to installed system image must be introduced,
# so that recompilation of kernel automatically updates also the
# drivers in system image to be flashed to the device.
kernel: $(INSTALLED_KERNEL_TARGET) kmodules $(NV_INSTALLED_SYSTEMIMAGE)

# 'kernel-build_only' is an isolated target meant to be used if _only_
# the build of the kernel and kernel modules is needed. This can be
# useful for example when measuring the build time of these
# components, but in most cases 'kernel-build_only' is probably not
# the target you want to use!
#
# Please use 'kernel'-target instead, it will also update the system
# image after compiling kernel and modules, and copy both the kernel
# and system images to correct locations for flashing.
kernel-build_only: $(BUILT_KERNEL_TARGET) kmodules-build_only
	@echo "kernel + modules built successfully! (Note, just build, no install done!)"

kernel-%: | $(NV_KERNEL_INTERMEDIATES_DIR)
	+$(hide) $(kernel-make) $*
ifneq ( , $(findstring $(BOARD_WLAN_DEVICE), wl12xx_mac80211 wl18xx_mac80211))
	+$(hide) $(compat-kernel-make) $*
endif

NV_KERNEL_BUILD_DIRECTORY_LIST := \
	$(NV_KERNEL_INTERMEDIATES_DIR) \
	$(NV_KERNEL_MODULES_TARGET_DIR) \
	$(NV_COMPAT_KERNEL_MODULES_TARGET_DIR) \
	$(NV_KERNEL_BIN_TARGET_DIR)

$(NV_KERNEL_BUILD_DIRECTORY_LIST):
	$(hide) mkdir -p $@

.PHONY: kernel kernel-% build_kernel_tests kmodules build_tegrawatch

# Set private variables for all builds. TODO: Why?
kernel build_kernel_tests kmodules build_tegrawatch $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_SRC_PATH := $(KERNEL_PATH)
kernel-%: PRIVATE_SRC_PATH := $(KERNEL_PATH)

kernel build_kernel_tests kmodules build_tegrawatch $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_TOPDIR := $(CURDIR)
kernel-%: PRIVATE_TOPDIR := $(CURDIR)

ifeq ($(TARGET_ARCH_KERNEL),arm64)
ifeq ($(TARGET_ARCH),arm64)
kernel build_kernel_tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_KERNEL_TOOLCHAIN := $(CURDIR)/$(TARGET_TOOLS_PREFIX)
kernel-%: PRIVATE_KERNEL_TOOLCHAIN := $(CURDIR)/$(TARGET_TOOLS_PREFIX)
else
kernel build_kernel_tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_KERNEL_TOOLCHAIN := $(ARM_EABI_TOOLCHAIN)/../../../aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
kernel-%: PRIVATE_KERNEL_TOOLCHAIN := $(ARM_EABI_TOOLCHAIN)/../../../aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
endif
kernel build_kernel_tests kmodules $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_KERNEL_CFLAGS := -mno-android
kernel-%: PRIVATE_KERNEL_CFLAGS := -mno-android
else
kernel build_kernel_tests kmodules build_tegrawatch $(dotconfig) $(BUILT_KERNEL_TARGET) $(TARGET_BUILT_KERNEL_DTB): PRIVATE_KERNEL_TOOLCHAIN := $(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.8/bin/arm-eabi-
kernel-%: PRIVATE_KERNEL_TOOLCHAIN := $(CURDIR)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.8/bin/arm-eabi-
endif

endif

endif
