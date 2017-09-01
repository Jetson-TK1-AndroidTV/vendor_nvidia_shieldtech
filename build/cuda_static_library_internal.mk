#
# Copyright (c) 2013-2016, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target static library
#

LOCAL_MODULE_CLASS            := STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX           := .a

ifeq ($($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT), 32)
 CUDA_EABI=armv7-linux-androideabi
else # implies 64 bits
 CUDA_EABI=aarch64-linux-androideabi
endif

ANDROID_CUDA_PATH := $(TOP)/vendor/nvidia/tegra/cuda-toolkit-7.0
CUDA_TOOLKIT_ROOT := $(ANDROID_CUDA_PATH)/targets/$(CUDA_EABI)

LOCAL_EXPORT_C_INCLUDE_DIRS := $(CUDA_TOOLKIT_ROOT)/include

include $(BUILD_SYSTEM)/binary.mk

CCBIN := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)CC)
NVCC := $(ANDROID_CUDA_PATH)/bin/nvcc

NVCC_CFLAGS := $(LOCAL_NVIDIA_NVCC_CFLAGS)
NVCC_LDFLAGS :=

ifeq ($(my_32_64_bit_suffix), 32)
 NVCC_CFLAGS += -DARCH_ARM
 NVCC_CFLAGS += -m32
 NVCC_LDFLAGS += -m32
else # implies 64 bits
 NVCC_CFLAGS += -DARCH_AARCH64
 NVCC_CFLAGS += -m64
 NVCC_LDFLAGS += -m64
endif

NVCC_CFLAGS += -gencode arch=compute_32,code=sm_32
NVCC_CFLAGS += -gencode arch=compute_53,code=sm_53
NVCC_CFLAGS += --use_fast_math
NVCC_CFLAGS += -O3
NVCC_CFLAGS += -Xptxas '-dlcm=ca'
NVCC_CFLAGS += -DDEBUG_MODE
NVCC_CFLAGS += -I$(CUDA_TOOLKIT_ROOT)/include

NVCC_LDFLAGS += -lib

cuda_objects := $(addprefix $(intermediates)/,$(cuda_sources:.cu=.o))

cuda_objdeps := $(cuda_objects) $(cuda_depinfo)

$(cuda_objects): PRIVATE_CC         := $(NVCC) -ccbin $(CCBIN)
$(cuda_objects): PRIVATE_CFLAGS     := $(NVCC_CFLAGS) \
                                       $(addprefix -Xcompiler \',$(addsuffix \',$(my_cflags)))
$(cuda_objects): PRIVATE_CPPFLAGS   := $(addprefix -Xcompiler \',$(addsuffix \',$(LOCAL_CPPFLAGS)))
$(cuda_objects): PRIVATE_C_INCLUDES := $(my_c_includes) $(my_target_c_includes)
$(cuda_objects): PRIVATE_MODULE     := $(LOCAL_MODULE)

ifneq ($(strip $(cuda_objects)),)
$(cuda_objects): $(intermediates)/%.o: $(LOCAL_PATH)/%.cu \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
	| $(NVCC) $(CCBIN)
	@echo "target CUDA: $(PRIVATE_MODULE) <= $<"
	@echo "C includes: $(PRIVATE_C_INCLUDES)"
	@mkdir -p $(dir $@)
	$(hide) $(PRIVATE_CC) \
	    $(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	    $(PRIVATE_CFLAGS) \
	    $(PRIVATE_CPPFLAGS) \
	    -o $@ -c $<
	$(hide) $(PRIVATE_CC) \
	    $(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	    $(PRIVATE_CFLAGS) \
	    $(PRIVATE_CPPFLAGS) \
	    -o $(patsubst %.o,%.d,$@) -MT $@ -M $<
	$(transform-d-to-p)

-include $(cuda_objects:%.o=%.P)

$(LOCAL_BUILT_MODULE): PRIVATE_CC := $(NVCC) -ccbin $(CCBIN)
$(LOCAL_BUILT_MODULE): PRIVATE_LDFLAGS := $(NVCC_LDFLAGS) \
                                           $(addprefix -Xcompiler , $(my_target_global_ldflags))
$(LOCAL_BUILT_MODULE): $(cuda_objects) \
	| $(NVCC) $(CCBIN)
	@mkdir -p $(dir $@)
	@rm -f $@
	@echo "target CUDA StaticLib: $(PRIVATE_MODULE) ($@)"
	$(hide) $(call split-long-arguments,$(PRIVATE_CC) $(PRIVATE_LDFLAGS) -o $@,$(filter %.o, $^))
	touch $(dir $@)export_includes

endif

#export_includes := $(intermediates)/export_includes
#$(export_includes): PRIVATE_EXPORT_C_INCLUDE_DIRS := $(LOCAL_EXPORT_C_INCLUDE_DIRS)
## Make sure .pb.h are already generated before any dependent source files get compiled.
#$(export_includes) : $(LOCAL_MODULE_MAKEFILE) $(proto_generated_headers)
#	@echo Export includes file: $< -- $@
#	$(hide) mkdir -p $(dir $@) && rm -f $@
#	$(hide) touch $@
