NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

LOCAL_MODULE_CLASS := SHARED_LIBRARIES

# Try guessing the .export file if not given
ifeq ($(LOCAL_NVIDIA_EXPORTS),)
LOCAL_NVIDIA_EXPORTS := $(subst $(LOCAL_PATH)/,,$(strip $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.export) $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE).export)))
endif

# Get absolute paths to .export files.
ifneq ($(LOCAL_NVIDIA_EXPORTS),)
LOCAL_NVIDIA_EXPORTS := $(if $(filter /%,$(LOCAL_NVIDIA_EXPORTS)), \
  $(LOCAL_NVIDIA_EXPORTS), \
  $(addprefix $(LOCAL_PATH)/,$(LOCAL_NVIDIA_EXPORTS)))
endif

ifdef NVIDIA_BUILD_MODULARIZATION_NAME
  ifeq ($(LOCAL_NVIDIA_EXPORTS),)
    # All modularized shared libraries must have an export file.
    # This is required to build a stub in the system builder (as well as any
    # stubs that other build modules may link against).
    $(error $(LOCAL_MODULE_MAKEFILE): Part of build module $(NVIDIA_BUILD_MODULARIZATION_NAME), export file required for shared library)
  endif
endif

my_module_skip_build := 0
ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
  #
  # Stubbed implementation
  #
  ifeq ($(LOCAL_NVIDIA_EXPORTS),)
    # If no export file is available, we can't build the stub.
    # Modularized components have already been checked above, so we can only
    # encounter this for shared libraries that haven't yet been assigned to a module.
    # In this case skip the stub and warn that the build may fail at a later stage.
    my_module_skip_build := 1

    $(warning $(LOCAL_MODULE_MAKEFILE): LOCAL_NVIDIA_EXPORTS not defined. Skipping shared library stub generation for $(LOCAL_MODULE), may cause build failures)
  else
    NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS += \
      LOCAL_NVIDIA_EXPORTS

    $(nvidia_build_modularization_stub_filter_locals)

    # Generated C file
    GEN := $(local-generated-sources-dir)/$(LOCAL_MODULE).c

    $(GEN): PRIVATE_INPUT_FILE := $(LOCAL_NVIDIA_EXPORTS)
    $(GEN): PRIVATE_CUSTOM_TOOL = python $(NVIDIA_GETEXPORTS) -c none none none $(PRIVATE_INPUT_FILE) > $@
    $(GEN): $(LOCAL_NVIDIA_EXPORTS) $(NVIDIA_GETEXPORTS)
		$(transform-generated-source)

    LOCAL_GENERATED_SOURCES := $(GEN)
  endif
endif


ifeq ($(my_module_skip_build),0)

include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architectures
my_module_multilib := both
endif

include $(NVIDIA_BASE)
include $(NVIDIA_WARNINGS)
include $(NVIDIA_COVERAGE)

LOCAL_LDFLAGS += -Wl,--build-id=sha1

# if .export files are given, add linker script to linker options and trigger the
# apicheck build.
ifneq ($(LOCAL_NVIDIA_EXPORTS),)
GEN := $(generated_sources_dir)/$(LOCAL_MODULE).script

$(GEN): PRIVATE_INPUT_FILE := $(LOCAL_NVIDIA_EXPORTS)
$(GEN): PRIVATE_CUSTOM_TOOL = python $(NVIDIA_GETEXPORTS) -script none none none $(PRIVATE_INPUT_FILE) > $@
$(GEN): $(LOCAL_NVIDIA_EXPORTS) $(NVIDIA_GETEXPORTS)
	$(transform-generated-source)

# This needs to be LOCAL_ADDITIONAL_DEPENDENCIES instead of LOCAL_GENERATED_SOURCES
# in case you don't have any non-generated sources (as in the static_and_shared_library case)
# The only thing that has an a order dependency on generated sources is normal objects,
# which wouldn't exist if you don't have any non-generated sources.
LOCAL_ADDITIONAL_DEPENDENCIES += $(GEN)

LOCAL_LDFLAGS += -Wl,--version-script=$(GEN)

ifeq ($(NVIDIA_APICHECK),1)
  LOCAL_REQUIRED_MODULES_$(TARGET_ARCH) += $(LOCAL_MODULE)_apicheck
  ifdef TARGET_2ND_ARCH
    LOCAL_REQUIRED_MODULES_$(TARGET_2ND_ARCH) += $(LOCAL_MODULE)_apicheck$(TARGET_2ND_ARCH_MODULE_SUFFIX)
  endif
endif

endif

include $(BUILD_SHARED_LIBRARY)
include $(NVIDIA_POST)

# rule for building the apicheck executable
ifneq ($(LOCAL_NVIDIA_EXPORTS),)
ifeq ($(NVIDIA_APICHECK),true)
ifneq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)

NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

NVIDIA_CHECK_MODULE_LINK := $(LOCAL_BUILT_MODULE)

include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architectures
my_module_multilib := both
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk
my_module_primary_arch_supported := $(my_module_arch_supported)

# Do both checks before including apicheck.mk, since it will clear all of the
# inputs to module_arch_supported.mk
ifdef TARGET_2ND_ARCH
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(NVIDIA_BUILD_ROOT)/apicheck.mk
endif
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
ifeq ($(my_module_primary_arch_supported),true)
include $(NVIDIA_BUILD_ROOT)/apicheck.mk
endif

# restore some of the variables for potential further use in caller
LOCAL_BUILT_MODULE := $(NVIDIA_CHECK_MODULE_LINK)
# Clear used variables
NVIDIA_CHECK_MODULE_LINK :=
my_module_arch_supported :=
my_module_primary_arch_supported :=
# Need to clear here, apicheck.mk doesn't include NVIDIA_POST
NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION :=

endif
endif
endif
else
    #needed to "close" the module if build is skipped
    include $(NVIDIA_POST_DUMMY)
endif

my_module_skip_build :=
