#
# Copyright (c) 2016, NVIDIA CORPORATION.  All rights reserved.
#
# only needed for internal builds
ifeq ($(wildcard $(TEGRA_TOP)/core-private),$(TEGRA_TOP)/core-private)

_nvidia_android_build_variables_file := $(PRODUCT_OUT)/android_build_variables.txt

# NOTE: TAB, trailing space and empty line are important, so please do not remove them!
define _nvidia_android_build_variable_add_line_nolf
	echo -ne "$(1) " >> $@

endef
# Unfortunately we don't have GNU make 4.0 $(file) available...
_nvidia_android_build_variable_add_line_if_not_empty = $(if $(1),$(call _nvidia_android_build_variable_add_line_nolf,$(1)))
_nvidia_android_build_variable_add_line = \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist     1,  500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist   501, 1000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  1001, 1500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  1501, 2000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  2001, 2500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  2501, 3000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  3001, 3500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  3501, 4000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  4001, 4500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  4501, 5000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  5001, 5500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  5501, 6000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  6001, 6500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  6501, 7000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  7001, 7500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  7501, 8000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  8001, 8500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  8501, 9000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  9001, 9500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist  9501,10000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist 10001,10500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist 10501,11000,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist 11001,11500,$(1))) \
$(call _nvidia_android_build_variable_add_line_if_not_empty,$(wordlist 11501,12000,$(1)))
_nvidia_android_build_variable              = $(1) := $($(1))\n
_nvidia_android_build_variable_optional     = $(if $(strip $($(1))),$(_nvidia_android_build_variable))
_nvidia_android_build_variable_add          = $(call _nvidia_android_build_variable_add_line,$(_nvidia_android_build_variable))
_nvidia_android_build_variable_add_optional = $(if $(strip $($(1))),$(call _nvidia_android_build_variable_add,$(1)))
_nvidia_android_build_variable_add_module   = $(call _nvidia_android_build_variable_add_line, \
	$(foreach _v,BUILT CLASS PATH REQUIRED TAGS MAKEFILE,$(call _nvidia_android_build_variable,ALL_MODULES.$(1).$(_v))) \
	$(foreach _v,FOR_2ND_ARCH INSTALLED,$(call _nvidia_android_build_variable_optional,ALL_MODULES.$(1).$(_v))) \
	$(call _nvidia_android_build_variable,ALL_DEPS.$(1).ALL_DEPS) \
	$(call _nvidia_android_build_variable_optional,PACKAGES.$(1).CERTIFICATE) \
)

# incremental build support: we need to pick up changes in Android makefiles
.PHONY: $(_nvidia_android_build_variables_file)
$(_nvidia_android_build_variables_file):
	rm -f $@
	$(call _nvidia_android_build_variable_add,ALL_MODULES)
	$(call _nvidia_android_build_variable_add,ALL_NVIDIA_MODULES)
	$(call _nvidia_android_build_variable_add,HOST_ARCH)
	$(call _nvidia_android_build_variable_add,HOST_DEPENDENCIES_ON_SHARED_LIBRARIES)
	$(call _nvidia_android_build_variable_add_optional,HOST_2ND_ARCH)
	$(call _nvidia_android_build_variable_add_optional,2ND_HOST_DEPENDENCIES_ON_SHARED_LIBRARIES)
	$(call _nvidia_android_build_variable_add,HOST_OUT)
	$(call _nvidia_android_build_variable_add,PRODUCT_COPY_FILES)
	$(call _nvidia_android_build_variable_add,RECOVERY_API_VERSION)
	$(call _nvidia_android_build_variable_add,RECOVERY_FSTAB_VERSION)
	$(call _nvidia_android_build_variable_add,TARGET_ARCH)
	$(call _nvidia_android_build_variable_add,TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES)
	$(call _nvidia_android_build_variable_add_optional,TARGET_2ND_ARCH)
	$(call _nvidia_android_build_variable_add_optional,2ND_TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES)
	$(foreach _m,$(ALL_MODULES),$(call _nvidia_android_build_variable_add_module,$(_m)))
	sed -i -e 's/^ \+//' $@

dev: $(_nvidia_android_build_variables_file)

_nvidia_android_build_variables_file :=
endif
