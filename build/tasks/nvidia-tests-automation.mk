ifneq ($(filter nvidia-tests-automation,$(MAKECMDGOALS)),)

_target_list_file := $(PRODUCT_OUT)/nvidia_tests/target.list
_target_list :=
_host_list_file := $(PRODUCT_OUT)/nvidia_tests/host.list
_host_list :=

define nvidia-test-automation-install-path
$(eval _binstalled := $(strip $(ALL_MODULES.$(1).BUILT_INSTALLED)))
$(eval _flist := $(strip $(ALL_NVIDIA_MODULES.$(1).INSTALLED_FILES)))
# Handle the case where module contains both real and fake targets.
$(foreach class,$(ALL_MODULES.$(1).CLASS),\
    $(if $(filter-out FAKE,$(class)),\
        $(eval _flist += $(firstword $(_binstalled)))\
    )\
    $(eval _binstalled := $(wordlist 2,$(words $(_binstalled)),$(_binstalled)))\
)

#Add target paths to right list
$(foreach part,$(_flist),\
    $(eval _dest := $(lastword $(subst :, ,$(part))))\
    $(if $(filter $(HOST_OUT)/%,$(_dest)),\
        $(eval _host_list += $(_dest))\
    ,$(if $(filter-out $(PRODUCT_OUT)/nvidia_tests/%,$(_dest)),\
        $(eval _target_list += $(_dest))\
    ,\
        $(error $(1) Should not install $(_dest) directly under nvidia_tests. Fix your Makefile!)\
    ))\
)
endef

_empty :=
define _rule_prefix

	$(_empty)
endef

define _dump-file-list
$($(1)_file): $($(1)) |$(dir $($(1)_file))
	rm -f $$@
	$(foreach line,$(subst $(2),,$($(1))),\
		$(_rule_prefix)printf '%s\n' '$(line)' >> $$@)
	touch $$@
endef

$(foreach module,$(ALL_NVIDIA_TESTS), \
    $(eval $(call nvidia-test-automation-install-path,$(module))))

$(eval $(call _dump-file-list,_target_list,$(PRODUCT_OUT)/))
$(eval $(call _dump-file-list,_host_list,$(HOST_OUT)/))

nvidia-tests-automation: $(_host_list) $(_host_list_file) \
                         $(_target_list) $(_target_list_file)

$(PRODUCT_OUT)/nvidia_tests:
	mkdir -p $@

_dump-file-list :=
_rule_prefix :=
nvidia-test-automation-install-path :=
_host_list :=
_host_list_file :=
_target_list :=
_target_list_file :=

endif
