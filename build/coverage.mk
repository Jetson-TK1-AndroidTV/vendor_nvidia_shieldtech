#
# Coverage instrumentation support
#

# If coverage instrumentation is enabled through the environment variable
ifneq ($(NVIDIA_COVERAGE_ENABLED),)
# If instrumentation isn't disabled for the module
ifneq ($(LOCAL_NVIDIA_NO_COVERAGE),true)

# Instrument the code
LOCAL_CFLAGS += -fprofile-arcs -ftest-coverage

# If coverage output isn't disabled
ifneq ($(LOCAL_NVIDIA_NULL_COVERAGE),true)
LOCAL_LDFLAGS += -lgcc -lgcov
else	# !LOCAL_NVIDIA_NULL_COVERAGE
# Link to NULL-output libgcov
LOCAL_STATIC_LIBRARIES += libgcov_null
LOCAL_LDFLAGS += -Wl,--exclude-libs=libgcov_null
endif	# LOCAL_NVIDIA_NULL_COVERAGE

endif	# !LOCAL_NVIDIA_NO_COVERAGE
endif	# NVIDIA_COVERAGE_ENABLED
