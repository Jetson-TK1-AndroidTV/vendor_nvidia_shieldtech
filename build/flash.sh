#!/bin/bash
#
# Copyright (c) 2013-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVFlash wrapper script for flashing Android from either build environment
# or from a BuildBrain output.tgz package. This script is usually
# called indirectly via vendorsetup.sh 'flash' function or BuildBrain
# package flashing script.
#

###############################################################################
# Usage
###############################################################################
usage()
{
    _margin="    "
    _cl="1;4;" \
    pr_info   "Usage:"
    pr_info   ""
    pr_info   "flash.sh [-h] [-n] [-o <odmdata>] [-s <skuid> [forcebypass]]" "$_margin"
    pr_info   "         [-d] [-N] [-u] [-v] [-O] [-F]" "$_margin"
    pr_info   "         [-f] [-i <USB instance>] [-- [optional args]]" "$_margin"

    pr_info_b "-h" "$_margin"
    pr_info   "  Prints help " "$_margin"
    pr_info_b "-n" "$_margin"
    pr_info   "  Skips using sudo on cmdline" "$_margin"
    pr_info_b "-o" "$_margin"
    pr_info   "  Specify ODM data to use" "$_margin"
    pr_info_b "-s" "$_margin"
    pr_info   "  Specify SKU to use, with optional forcebypass flag to nvflash" "$_margin"
    pr_info_b "-f [NVFLASH ONLY]" "$_margin"
    pr_info   "  For fused devices. uses blob.bin and bootloader_signed.bin when specified." "$_margin"
    pr_info_b "-d" "$_margin"
    pr_info   "  Dry-run. Exits after printing out the final flash command" "$_margin"
    pr_info_b "-i" "$_margin"
    pr_info   "  USB instance" "$_margin"
    pr_info_b "-u" "$_margin"
    pr_info   "  Unattended/Silent mode. (\"No questions asked.\")" "$_margin"
    pr_info_b "-v" "$_margin"
    pr_info   "  Verbose mode" "$_margin"
    pr_info_b "-F" "$_margin"
    pr_info   "  Ignores errors." "$_margin"
    pr_info_b "-O" "$_margin"
    pr_info   "  Offline Mode." "$_margin"
    pr_info_b "-N" "$_margin"
    pr_info   "  Don't track. Disables board tracking." "$_margin"
    pr_info   ""
    pr_info__ "Environment Vairables:" "$_margin"
    pr_info   "PRODUCT_OUT    - target build output files (default: $ROOT_PATH)" "$_margin"
    [[ -n "${PRODUCT_OUT}" ]] && \
    pr_warn   "                     \"${PRODUCT_OUT}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   "HOST_BIN       - path to flash executable (default: $ROOT_PATH)" "$_margin"
    [[ -n "${HOST_BIN}" ]] && \
    pr_warn   "                     \"${HOST_BIN}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   "BOARD          - Select board without a prompt. (default: None)" "$_margin"
    [[ -n "${BOARD}" ]] && \
    pr_warn   "                     \"${BOARD}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   ""
}

# Help message to print when we couldn't retrieve an object
help_missing_obj() {
    [ -z "$_force" ] && {
    pr_info ""
    _cl="1;4;" \
    pr_info "DEVICE RESOURCES NOT FOUND"
    [ -n "$1" ] && pr_info "" && pr_warn  "[Missing $1]"
    pr_info ""
    [ "$tns_online" != "1" ] && {
        pr_info "TNSPEC Server is offline."
        pr_info "Please try again in a few minutes OR use '-F' option to ignore missing resources."
    } || {
        pr_info "You're seeing this because resources registered for this device were not found."
        pr_info "While this not common, you have 3 options."
        pr_info ""
        pr_info "   1) File a bug for missing resources with OBJ keys."
        pr_info ""
        pr_info "   2) 'flash register' to upload resources from your device."
        pr_info "       Use this option if you know your device has correct resources."
        pr_info ""
        pr_info "   3) Flash with '-F' option to ignore missing resources."
        pr_info ""
    }
    exit 1
    }
}

###############################################################################
# TNSPEC Platform Handler
###############################################################################

#
# tnspec_setup nct source [args]
# - Sets up platform data using various sources.
#
# This is the main platform handler where the final TNSPEC (NCT) gets generated.
#
# Following sources are supported:
#   o tnspec          - path to the tnspec file
#   o auto            - use the tnspec from the device
#   o manual [method] - switch SKU from compatible HW list. 'method' is used to
#                       use an alternate flashing method if availble.
#   o board  [target] - builds TNSPEC based on the flash 'target'
#
tnspec_setup()
{
    specid=''
    local nctbin="$1"
    local src="$2"
    local arg="$3"

    [ -z "$nctbin" ] && {
        pr_err "nctbin must be specified." "tnspec_setup: "
        exit 1
    }

    [ -e "$nctbin" ] && [ ! -w "$nctbin" ] && _su rm $nctbin

    case $src in
       tnspec)
           tnspec_setup_tnspec $nctbin $arg ;;
       auto)
           tnspec_setup_auto $nctbin $arg ;;
       manual)
           tnspec_setup_manual $nctbin $arg ;;
       board)
           tnspec_setup_board $nctbin $arg ;;
       *)
           pr_err "Unsupported source [$src]" "tnspec_setup: " ;;

    esac
    pr_info "NCT created." "tnspec_setup: "

    local sw_specs=$(tnspec spec list all -g sw)
    if ! _in_array $specid $sw_specs; then
        pr_warn "TNSPEC ID '$specid' is not supported. Please file a bug." "tnspec_setup: "
        exit 1
    fi

    pr_info "Check if NCT needs to be updated from SW" "tnspec_setup: "
    nct_update_hw_override $nctbin $nctbin.updated $specid
    nct_diff $nctbin $nctbin.updated &&
        pr_info_b "[hw_override] TNSPEC unchanged." "tnspec_setup: " ||
        { cp $nctbin.updated $nctbin; pr_warn "TNSPEC has been updated." "tnspec_setup: "; }

    pr_info "See if we need to update TNSPEC from BOARD_UPDATE" "tnspec_setup: "
    nct_update $nctbin $nctbin.updated VAR BOARD_UPDATE
    nct_diff $nctbin $nctbin.updated &&
        pr_info_b "[BOARD_UPDATE] Nothing to update." "tnspec_setup: " ||
        { cp $nctbin.updated $nctbin; pr_warn "TNSPEC has been updated." "tnspec_setup: "; }

    tnspec_get_sw_variables

    pr_ok "OK!" "tnspec_setup: "
}

#
# tnspec_setup_tnspec nct tnspec_path
# - Sets up NCT from a tnspec file specified
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_tnspec() {
    local nctbin="$1"
    local src="$2"

    [ ! -f "$src" ] && {
        pr_err "'$src' doesn't exist." "tnspec_setup_tnspec: "
        exit 1
    }
    _tnspec nct new -o $nctbin < $src
    specid="$(_tnspec spec get id < $src).$(_tnspec spec get config < $src)"
}

#
# tnspec_setup_board nct flash_target
# - Sets up NCT using flash target
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_board() {
    local nctbin="$1"
    local target="$2"

    local boards=$(tnspec spec list all -g hw)
    ! _in_array "$target" $boards && {
        pr_err "HW Spec ID '$target' is not supported." "tnspec_setup_board: "
        exit 1
    }

    local hwid=$(tnspec spec get $target.id -g hw)
    if [ -z "$hwid" ]; then
        pr_err "Couldn't find 'id' field from HW Spec '$target'." "tnspec_setup_board: " >&2
        pr_warn "Dumping HW Spec '$target'." "tnspec_setup_board: " >&2
        tnspec spec get $target -g hw >&2
        exit 1
    fi

    local config=${tnspecid_config_override:-$(tnspec spec get $target.config -g hw)}
    config=${config:-default}
    specid=$hwid.$config

    if [ -z "$specid" ]; then
        pr_err "Couldn't find TNSPEC ID '$specid'. Spec needs to be updated." "tnspec_setup_board: ">&2
        exit 1
    fi

    tnspec nct new $target -o $nctbin

    # Update config field if tnspecid_config_override is set
    [ -n "$tnspecid_config_override" ] && {
        nct_update $nctbin $nctbin.updated VAL "config=$config"
        nct_diff $nctbin $nctbin.updated || cp $nctbin.updated $nctbin
    }
}

#
# tnspec_setup_auto nct
# - Sets up NCT using TNSPEC from device
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_auto() {
    local nctbin="$1"
    local method="$2"
    tnspec_detect_hw $nctbin

    # Use an alternate method if specified
    [ -n "$method" ] && {
        local alt_methods="$(tnspec_get_sw $specid.alt_methods)"
        _in_array $method $alt_methods && {
            pr_info_b "··················································"
            pr_info   ""
            pr_cyan   "     USING '$method' FLASHING METHOD"
            pr_info   ""
            pr_info_b "··················································"
            flash_method=$method
        } || {
            pr_err "Alternate flashing method '$method' is not supported." \
                   "tnspec_setup_auto: "
            pr_info__ "Supported Flashing Methods:"
            pr_info "$alt_methods"
            exit 1
        }
    }
}

#
# tnspec_setup_manual nct [method]
# - Sets up NCT using TNSPEC from device
#
# 'manual' allows users to switch to a different SKU as long as they shared the
# same HW ID which is the first part of TNSPEC ID. Additionally, 'method' can
# be passed to choose alternate flashing methods if supported.
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
# [args]
# method
# - if set, it will use alternate methods for flashing.
#
tnspec_setup_manual() {
    local nctbin="$1"
    local method="$2"

    # Detect HW
    tnspec_detect_hw $nctbin

    [ "$_unattended" == "1" ] && [ -z "$TNSPEC_ID" ] && {
        pr_err "TNSPEC_ID must be set for unattended mode." "tnspec_setup_manual: "
        exit 1
    }

    local hwid=$(_tnspec nct dump tnspec -n $nctbin | _tnspec spec get id)
    local _sw_specs=$(tnspec spec list $hwid -g sw)

    # Check tnspec with alternate flashing methods
    declare -A alt_methods
    local tns m
    for tns in $_sw_specs; do
        for m in $(tnspec_get_sw $tns.alt_methods)
        do
            # Save off supported tnspecs per method
            alt_methods[$m]="${alt_methods[$m]}$tns "
        done
    done

    # Save methods
    local methods="${!alt_methods[*]}"
    [ -n "$methods" ] && {
        pr_info_b "··················································"
        pr_info_b "FOLLOWING ALTERNATE FLASHING METHODS ARE AVAILABLE"
        pr_cyan   "$methods"
        pr_info   ""
        pr_info   "   To select a method, type 'method <method>'"
        pr_info_b "     e.g. >> method $m"
        pr_info   "   To reset, type 'method'"
        pr_info_b "     e.g. $m >> method"
        pr_info   ""
        for m in $methods; do
            pr_info_b "$m" "▸ "
            # Print description if available
            local alt_desc="$(tnspec_get_sw $hwid.default.alt_methods_descs.$m)"
            [ -n "$alt_desc" ] &&
                pr_warn "▮ $alt_desc" "  "
            for tns in ${alt_methods[$m]}; do
                pr_info "  $tns"
            done
            pr_info ""
        done
        pr_info_b "··················································"
    }

    [ -n "$method" ] && {
        _in_array $method $methods || {
            pr_err_b "Alternate method '$method' is not supported for this HW." "manual: "
            [ "$_unattended" == "1" ] && exit 1
            pr_warn "Ignoring '$method'" "manual: "
            pr_info_b "··················································"
            method=""
        }
    }

    local _new_specid=${TNSPEC_ID:-}
    [ -z "$_new_specid" ] && {
        pr_info__ "Compatible HW"
        tnspec spec list $hwid -g sw -v
        pr_info ""
        pr_info__ "Current HW"
        local bold=$(tnspec spec list $specid -g sw -v)
        pr_ok "$bold"
        pr_info ""
        local ps=">> "
        [ -n "$method" ] && ps="$method >> "
        _choose_hook=_choose_hook_setup_manual _choose "$ps" "$_sw_specs" _new_specid
    }

    [ -n "$method" ] && ! _in_array $_new_specid ${alt_methods[$method]} && {
        pr_err "'$_new_specid' doesn't support '$method' flashing method" "manual: "
        exit 1
    }

    ! _in_array $_new_specid $_sw_specs && {
        pr_err "HW Spec ID '$_new_specid' is not supported." "tnspec_setup_manual: "
        exit 1
    }

    # Set flash_method
    flash_method=$method

    specid=$_new_specid

    # Update config
    local config=${specid##*.}
    nct_update $nctbin $nctbin.updated VAL "config=$config"
    nct_diff $nctbin $nctbin.updated &&
        pr_info_b "[MANUAL] 'config' didn't change." "tnspec_setup_manual: " ||
        { cp $nctbin.updated $nctbin;
        pr_warn "[MANUAL] 'config' changed to $config" "tnspec_setup_manual: "; }
}

# Choose hook for tnspec_setup_manual
_choose_hook_setup_manual() {
    input_hooked=""
    if [ "$1" == "method" ]; then
        [ -z "$2" ] && {
            method=""
            query_hooked=">> "
            return 0
        }
        _in_array "$2" $methods && {
            method="$2"
            query_hooked="$method >> "
        } || {
            pr_err "Unsupported method." "manual: "
        }
    elif [ "$1" == "" ]; then
        pr_err "You need to enter something."
    else
        return 1
    fi
    return 0
}

#
# tnspec_detect_hw nct
# Automatically detect HW type and generate NCT if necessary
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_detect_hw() {
    local nctbin="$1"
    [ -z "$nctbin" ] && { pr_err "'nctbin' not specificed." "tnspec_detect_hw: "; exit 1; }

    pr_info "Detecting Hardware...." "tnspec_detect_hw: "

    nct_read $nctbin > $TNSPEC_OUTPUT || {
                   pr_info   ""
        _cl="1;4;" pr_err    "SOMETHING WENT WRONG."
                   pr_info   ""
        _cl="4;"   pr_info__ "Run it again with verbose mode (flash -v) for logs"
                   pr_info   ""

        pr_err "Couldn't find TNSPEC ID. Try recovery mode." "tnspec_detect_hw: ">&2
        exit 1
    }

    # Dump NCT partion
    pr_info "NCT Found. Checking TNSPEC."  "tnspec_detect_hw: "

    local hwid=$(tnspec nct dump spec -n $nctbin 2> $TNSPEC_OUTPUT | _tnspec spec get id -g hw)
    if [ -z "$hwid" ]; then
        pr_err "NCT's spec partition or 'id' is missing in NCT." "tnspec_detect_hw: "
        pr_warn "Dumping NCT..." "tnspec_detect_hw: "
        tnspec nct dump -n $nctbin >&2
        exit 1
    else
        pr_info "TNSPEC found. Retrieving TNSPEC ID" "tnspec_detect_hw: "
        local config=$(tnspec nct dump spec -n $nctbin 2> $TNSPEC_OUTPUT | _tnspec spec get config -g hw)
        config=${config:-default}
        local _tns_id=$hwid.$config

        pr_ok_b "TNSPEC ID: $_tns_id" "tnspec_detect_hw: "
        nct_upgrade_tnspec $nctbin > $TNSPEC_OUTPUT || return 1
        specid=$_tns_id
    fi
}

tnspec_get_sw_variables() {
    local sw_vars="signed_vars cfg bct dtb sku odm cfg_override skip_sanitize"
    if [ "$flash_driver" == "tegraflash" ]; then
        sw_vars="$sw_vars cfg_override"
        [ "$(getprop version)" == "2" ] && {
            # Dynamically append all keys
            local k
            for k in $(tnspec_get_sw $specid.bct_configs.); do
                sw_vars="$sw_vars bct_configs.$k"
            done
            # MTS
            sw_vars="$sw_vars preboot bootpack"
        }
    elif [ "$flash_driver" == "nvflash" ]; then
        sw_vars="$sw_vars minbatt no_disp skip_nct preboot bootpack"
    fi

    local _v v
    for v in $sw_vars; do
        _v="$(tnspec_get_sw $specid.$v)" || {
            pr_err "Couldn't query $spec.$v" "tnspec_get_sw_variables: "
            exit 1
        }

        # Convert dots to underscores in case we need to read nested key values.
        # e.g. aa.bb.cc => aa_bb_cc
        v=${v//./_}
        eval "sw_var_$v=\"$_v\""
    done
}

_reboot() {
    if [ "$flash_driver" == "tegraflash" ]; then
        $(nvbin $(getprop tegradevflash)) $instance --reboot coldboot > $TNSPEC_OUTPUT
    else
        # Assume nvflash
        _nvflash --force_reset reset 100 > $TNSPEC_OUTPUT
        resume_mode=0
    fi
}

###############################################################################
# NCT Processors
###############################################################################

#
# nct_update <source nct> <updated nct> <format> <values ..>
# - takes override values in various formats (vals, json, variable names)
#
# [args]
# source nct, updated nct
# - Input and output nct files
# type value
# - It can be of the following types:
#   VAR  - takes value as a variable name and evaluates that variable to update
#          NCT. (_JSON will be also evaluated for JSON type)
#          e.g.
#            my_variable="sn=hello;modulex.uuid=nnnn-nnn-nnn"
#            nct_update n1 n2 VAR my_variable
#   VAL  - takes the simple update notation. e.g. sn=123456
#   JSON - takes the JSON format. e.g. '{"sn" : "123456"}'
#
# [returns]
# 0 - Success
#
# May be terminated early if values passed are in a bad format.
#
nct_update() {
    [[ $# < 3 ]] && {
        pr_err "requires at least 3 arguments." "nct_update: "
        return 1
    }
    local src=$1
    local target=$2
    local format=$3
    local v
    shift 3
    [ ! -f "$src" ] && {
        pr_err "$src doesn't exist" "nct_update: "
        return 1
    }
    local tmp=$src.tmp

    _su rm $tmp $target 2> /dev/null
    cp $src $tmp
    cp $src $target
    for v; do
        local hw=""
        local hw_json=""
        if [ "$format" == "VAR" ]; then
            hw=$(eval echo "\$${v}")
            hw_json=$(eval echo "\$${v}_JSON")
        elif [ "$format" == "VAL" ]; then
            hw="$v"
        elif [ "$format" == "JSON" ]; then
            hw_json="$v"
        fi
        [ -n "$hw" ] && pr_ok_bl "Updating TNSPEC [SIMPLE]: '$hw'" "tnspec_update: "
        [ -n "$hw_json" ] && pr_ok_bl "Updating TNSPEC [JSON]: '$hw_json'" "tnspec_update: "
        [ -n "$hw" ] || [ -n "$hw_json" ] &&
            TNSPEC_SET_HW="$hw" TNSPEC_SET_HW_JSON="$hw_json" \
                _tnspec nct update -o $target -n $tmp <<< ""
        cp $target $tmp
    done
    [ -f "$tmp" ] && rm $tmp

}

#
# nct_update_hw_override <source nct> <target nct> <tnspec id>
# - Update NCT using TNSPEC ID.hw_override
#
# Update TNSPEC field in NCT if hw_override key is found in SW spec mapped by
# TNSPEC ID. "hw_override" is an array type, a user can specify a sequence of
# override operations to take place.
#
# hw_override_json takes override keys in JSON format.
#
# [args]
# nct1, nct2
# - nct files
# tnspec id
# - Used to map to a sw spec that defines hw_override/_json
#
# [returns]
# 0 - Success
# 1 - otherwise
#
nct_update_hw_override() {
    [[ $# < 3 ]] && {
        echo $*
        pr_err "requires at least 3 arguments." "nct_update_hw_override: "
        return 1
    }
    local _tnspecid=$3
    local _ifs=$IFS
    IFS=$'\n'
    local _hw_override
    _hw_override=($(tnspec_get_sw $_tnspecid.hw_override)) || exit 1

    local i
    for ((i=0; i<${#_hw_override[@]};i++)); do
        pr_ok "[$i] Found 'hw_override' : '${_hw_override[$i]}'" \
            "nct_update_hw_override: " > $TNSPEC_OUTPUT
        _hw_override[$i]="'${_hw_override[$i]}'"
    done
    local _hw_override_json=($(tnspec_get_sw $specid.hw_override_json))
    for ((i=0; i<${#_hw_override_json[@]};i++)); do
        pr_ok "[$i] Found 'hw_override_json' : '${_hw_override_json[$i]}'" \
            "nct_update_hw_override: " > $TNSPEC_OUTPUT
        _hw_override_json[$i]="'${_hw_override_json[$i]}'"
    done
    IFS=$_ifs
    eval nct_update $1 $2 VAL ${_hw_override[@]}
    _su rm $2.tmp 2> /dev/null
    cp $2 $2.tmp
    eval nct_update $2.tmp $2 JSON ${_hw_override_json[@]}
}

#
# nct_diff nct1 nct2 [format]
# - Print differences between two NCTs
#
# [args]
# nct1, nct2
# - nct files
# format
# - target entry to compare. "tnspec" is the default.
#
# [returns]
# 0 - When the target entry of both ncts are identical
# 1 - Otherwise
#
nct_diff() {
    local n1="$1"
    local n2="$2"
    local format=${3:-tnspec}

    [ -f "$n1" ] && [ -f "$n2" ] || {
        pr_err "File(s) not found. ('$n1' or '$n2')" "nct_diff: "
        exit 1
    }
    diff -b $n1 $n2 > /dev/null
    if [ $? != 0 ]; then
        _tnspec nct dump $format -n $n1 > $n1.dump$format
        _tnspec nct dump $format -n $n2 > $n2.dump$format
        diff -u $n1.dump$format $n2.dump$format
        rm $n1.dump$format $n2.dump$format
        return 1
    fi
    return 0
}

#
# nct_upgrade_tnspec nct
# - upgrades the old format NCT to a newer version that has the full tnspec.
#
# Old tnspec tool does not export the entire tnspec in NCT, which is critical
# data to reconstruct NCT. This function reads a NCT file and checks if the new
# tnspec is found. If found, it returns immediately, otherwise it attempts to
# find the original HW spec using TNSPEC ID found from the source nct (stored
# in "spec" field), and rebuilds a new NCT. After this, the newly creatly NCT
# is updated with SN from the source NCT.
#
# [args]
# nct
# - nct file to upgrade
#
# [prereq]
# tnspec.json must contain the matching HW spec.
#
# [returns]
# 0 - Success
# 1 - Otherwise
#
nct_upgrade_tnspec() {

    local nctbin=$1
    local spec
    spec="$(_tnspec nct dump tnspec -n $nctbin 2> $TNSPEC_OUTPUT)" || {
        pr_err "NCT doesn't seem valid" "TNSPEC Upgrade: " >&2
        return 1
    }
    if [ -z "$spec" ]; then
        pr_warn "Found old spec. Trying to convert to a newer version." "TNSPEC Upgrade: " >&2

        pr_info "Dumping old NCT" "TNSPEC Upgrade: "
        tnspec nct dump -n $nctbin 2> $TNSPEC_OUTPUT

        spec=$(_tnspec nct dump spec -n $nctbin 2> $TNSPEC_OUTPUT)

        [ -z "$spec" ] && {
            pr_err "Couldn't convert old format to new format." "TNSPEC Upgrade: " >&2
            return 1
        }

        local tnsid="$(_tnspec spec get id <<< $spec).$(_tnspec spec get config <<< $spec)"
        [ "$tnsid" == "." ] && {
            pr_err "TNSPEC ID not found." "TNSPEC Upgrade: " >&2
            return 1
        }

        # There are really only a couple of  fields we need to import from the
        # old NCT. Instead of sourcing it from tnspec.json, we just hardcode
        # them here.
        local preserve_list="serial:sn wcc:wcc"
        local t _override _override_JSON
        for e in $preserve_list; do
            local nct_key="${e%:*}"
            local tnspec_key="${e#*:}"
            t="$(_tnspec nct dump $nct_key -n $nctbin 2> $TNSPEC_OUTPUT)"
            [ -n "$t" ] && _override+="${_override:+;}$tnspec_key=$t"
        done

        # 'misc' under 'spec'
        _override_JSON="$(_tnspec nct dump spec -n $nctbin 2> $TNSPEC_OUTPUT)"

        local hwids=($(tnspec spec list $tnsid -g hw))
        local hwid=${hwids[0]}

        # Check for tie-breakers
        [ ${#hwids[@]} -gt 1 ] && {
            tiebreakers="$(tnspec spec get $tnsid._nct_tie_breakers. -g sw)"
            for e in ${hwids[@]}; do
                _in_array $e $tiebreakers && {
                    tbs="$(tnspec spec get $tnsid._nct_tie_breakers.$e -g sw)"
                    local found=1
                    for tb in $tbs; do
                        _tnspec nct dump -n $nctbin 2> $TNSPEC_OUTPUT | grep "$tb" > /dev/null || {
                            found=0
                            break
                        }
                    done
                    [ "$found" == "1" ] && {
                        hwid=$e
                        pr_cyan "Found a tie-breaker. Using '$e'" "TNSPEC Upgrade: " >&2
                        break
                    }
                }
            done
        }

        [ -n "$hwid" ] && {
            pr_ok  "FOUND matching board name [$hwid]" "TNSPEC Upgrade: "
            pr_info "[$hwid] $(tnspec spec get $hwid.desc -g hw)" "TNSPEC Upgrade: "
            TNSPEC_SET_HW="$_override" TNSPEC_SET_HW_JSON="$_override_JSON" \
                tnspec nct new $hwid -o $nctbin.tmp &&
                _su cp $nctbin.tmp $nctbin || {
                    pr_err "Convert failed." "TNSPEC Upgrade: " >&2
                    return 1; }
        } || {
            pr_err "Couldn't find HW ID." "TNSPEC Upgrade: " >&2
            return 1
        }
        pr_ok_b "Successfully converted to new TNSPEC format." "TNSPEC Upgrade: " >&2
        _tnspec nct dump -n $nctbin
    fi
}

#
# nct_read nct
# - Reads NCT from device.
#
# [args]
# nct
# - Saves to 'nct'

# [returns]
# 0 - NCT dowloaded successfully
# 1 - Otherwise
nct_read() {
    local nctbin=$1
    part_read NCT $nctbin && __tnspec nct dump -n $nctbin > $TNSPEC_OUTPUT || {
        pr_err "Failed to read NCT" "nct_read: " >&2
        return 1
    }
}

#
# nct_write nct
# - writes nct to device
#
# [args]
# nct
# - NCT to write to device
#
# [returns]
# 0 - Wrote NCT to device successfully
# 1 - Otherwise
#
nct_write() {
    part_write NCT $1
}

###############################################################################
# TNSPEC Command Wrappers
###############################################################################

# tnspec w/o spec
_tnspec() {
    $tnspec_bin "$@" || {
        pr_err "tnspec tool ran into an error." "_tnspec: " >&2
        exit 1
    }
}

# tnspec - expecting error handlers
__tnspec() {
    $tnspec_bin "$@"
}

# tnspec wrapper
tnspec() {
    local tnspec_spec=$PRODUCT_OUT/tnspec.json
    local tnspec_spec_public=$PRODUCT_OUT/tnspec-public.json

    if [ ! -f "$tnspec_spec" ]; then
        if [ ! -f "$tnspec_spec_public" ]; then
            pr_err "Error: tnspec.json doesn't exist." "TNSPEC: " >&2
            return
        fi
        tnspec_spec=$tnspec_spec_public
    fi

    _tnspec "$@" -s $tnspec_spec
}

# tnspec spec get wrapper (SW)
tnspec_get_sw() {
    # TODO: add conditionals (e.g. fused)

    TNSPEC_SET_SW="$OVERRIDE_SW" \
    TNSPEC_SET_SW_JSON="$OVERRIDE_SW_JSON" tnspec spec get "$1" -g sw
}

###############################################################################
# TNSPEC Platform Handler MAIN
###############################################################################
flash_main() {
    # Check for use of restricted internal env variables (TNSPEC_SET_*)
    tnspec_check_env

    # Get flash_driver
    settings=$(tnspec spec get settings.flash) || exit 1

    # Flash driver initialization
    driver_init

    if [ -z "$settings" ]; then
        pr_err "settings not found in $PRODUCT_OUT/tnspec.json." "tnspec_init: "
        pr_err "fall back to legacy mode" "tnspec_init: "
        flash_main_legacy
        exit
    fi
    tnspec_server=${TNSPEC_SERVER:-$(tnspec spec get settings.tnspec_server)}

    if [ "$flash_interface" == "legacy" ]; then
        flash_main_legacy
        exit
    fi

    # Make sure we have all the tools
    check_tools_nvidia

    # Check for deprecated options
    tnspec_check_options

    # Initialization
    tnspec_init

    # Get command
    tnspec_command

    case $command in
        auto)
            tnspec_cmd_auto auto "${command_args[@]}"
            ;;
        manual)
            tnspec_cmd_auto manual "${command_args[@]}"
            ;;
        factory)
            tnspec_cmd_factory_reset "${command_args[@]}"
            ;;
        recovery)
            tnspec_cmd_factory_recovery "${command_args[@]}"
            ;;
        tnspec)
            tnspec_cmd_tnspec "${command_args[@]}"
            ;;
        register)
            tnspec_cmd_register update "${command_args[@]}"
            _reboot
            ;;
        test)
            nct_upgrade_tnspec "${command_args[@]}"
            ;;
    esac

    if [ "$_no_track" != "1" ] && [ -x "$HOST_BIN/track.sh" ]; then
        if [ "$command" = "auto" ] || [ "$command" == "recovery" ]; then
            (PRODUCT_OUT="$PRODUCT_OUT" $HOST_BIN/track.sh "$(db_tnspec_get)" &)
        fi
    fi

    exit 0
}

driver_init() {
    flash_driver=$(_getprop driver)
    flash_interface=$(_getprop interface)

    # Common
    _prop_default_board=$(_getprop default_board)

    # Tegraflash initialization
    if [ "$flash_driver" == "tegraflash" ]; then
        _prop_default_cmd=$(_getprop default_cmd)
        _prop_version=($(_getprop version))
        _prop_bl=($(_getprop bl))
        _prop_bl_mb2=($(_getprop bl_mb2))
        _prop_applet=($(_getprop applet))
        _prop_chip=$(_getprop chip)
        _prop_tegrarcm=$(_getprop tegrarcm)
        _prop_tegradevflash=$(_getprop tegradevflash)
        _prop_arg_secure=("" "--securedev")

        # Default properties for Tegraflash
        [ -z "$_prop_bl" ]       && _prop_bl=(cboot.bin cboot.bin.signed)
        [ -z "$_prop_applet" ]   && _prop_applet=(nvtboot_recovery.bin rcm_1_signed.rcm)
        [ -z "$_prop_chip" ]     && _prop_chip=0x21
        [ -z "$_prop_tegrarcm" ] && _prop_tegrarcm=tegrarcm
        [ -z "$_prop_tegradevflash" ] && _prop_tegradevflash=tegradevflash
    else
        # NVFLASH (don't bother getting data from tnspec.json)
        _prop_bl=(bootloader.bin bootloader_signed.bin)
        _prop_arg_blob=("" "--blob blob.bin")
    fi
}

getprop() {
    local name=_prop_$1
    eval local data=\$$name
    # Read fused item if fused.
    [ "$_fused" == "1" ] && {
        eval local count=\${#$name[@]}
        if [ "$count" == "2" ]; then
            eval data=\${$name[1]}
        fi
    }
    echo $data
}

_getprop() {
    _tnspec spec get $1 <<< $settings
}


tnspec_init() {
    nctbin=nct.bin

    if [ -z "$flash_driver" ]; then
        pr_err "settings.flash.driver is not defined in $PRODUCT_OUT/tnspec.json" "tnspec_init: "
        exit 1
    fi

    # Read CID
    tnspec_read_cid

    # Create workspace
    tnspec_init_workspace

    # Initializes OBJ Manager
    obj_init

    # Initializes TNSPEC Server Manager
    server_init

    # Check additional dependencies
    check_deps

    # Check status
    [ "$(flash_status)" == "flashing" ] || [ "$(flash_status)" == "aborted" ] && {
        pr_info ""
        pr_err  "********************  WARNING  ************************"
        pr_info ""
        pr_warn "             FLASHING ABORTED PREVIOUSLY "
        pr_warn "       ('recovery' may be enforced if necessary)"
        pr_info ""
        pr_err  "*******************************************************"
    }
    return 0
}

_tnspec_command_menu() {
    pr_warn "-"
    pr_ok_b "auto     [method] - flash your device automatically"
    pr_info "manual   [method] - choose a different or reworked SKU compatible with your device"
    pr_info "recovery [hw]     - recover your device or change it to different HW"
    pr_info "tnspec            - view or update TNSPEC stored in device"
    pr_info "register          - register this device"
    pr_err  "factory           - factory use only (your device information will be initialized)"
    pr_info ""
}

tnspec_command() {
    # private commands : register, factory
    local supported_cmds="auto manual recovery tnspec register factory test help"

    command=${commands[0]:-$(getprop default_cmd)}
    command_args=(${commands[@]:1})

    # command override
    if [ -n "$board" ] && [ "$command" == "" ]; then
        pr_warn "BOARD ($board) is set. Forcing 'recovery' mode" "command: "
        command=recovery
    elif [ -z "$board" ] && [ "$_unattended" == "1" ]; then
        [ "$command" == "" ] && {
            pr_warn "<command> not set. Non-interactive shell." "command: "
            board=$(getprop default_board)
            [ -n "$board" ] && {
                pr_warn "default_board ($board) found. Forcing 'recovery'" "command: "
                command=recovery
            } || {
                pr_warn "No default_board set. Forcing 'auto'" "command: "
                command=auto
            }
        }
    fi

    # TODO: get TNSPEC stoage option from TNPSPEC:HW:tnspec_storage
    #       (add this dynamically in db_tnspec_register)
    # Check if target board doesn't store TNSPEC.
    [ -n "$board" ] && {
        local tnsid="$(tnspec spec get $board.id -g hw).$(tnspec spec get $board.config -g hw)"
        [ "$(tnspec_get_sw $tnsid.skip_nct)" == "true" ] && {
            # Check if TNSPEC is registered in the server
            pr_warn_b "'$board' does not store TNSPEC in the device. Checking TNSPEC Server.." "command: "
            _in_array "$command" recovery auto manual &&
            [ -z "$(server_only=1 db_tnspec_get)" ] && {
                pr_err "TNSPEC not found in the server. Force 'factory' ('$command' ignored)" "command: "
                command=factory
            }
        }
    }

    while ! _in_array "$command" $supported_cmds; do
        _tnspec_command_menu
        [ "$_unattended" == "1" ] && {
            pr_err_b "Unsupported command [$command]" "command: "
            exit 1
        }
        local _commands
        read -p ">> " _commands
        _commands=($_commands)
        command=${_commands[0]}
        command_args=(${_commands[@]:1})
    done
}

tnspec_check_env() {
    [ -n "$TNSPEC_SET" ]      || [ -n "$TNSPEC_SET_JSON" ] ||
    [ -n "$TNSPEC_SET_HW" ]   || [ -n "$TNSPEC_SET_HW_JSON" ] ||
    [ -n "$TNSPEC_SET_SW" ]   || [ -n "$TNSPEC_SET_SW_JSON" ] ||
    [ -n "$TNSPEC_SET_BASE" ] || [ -n "$TNSPEC_SET_BASE_JSON" ] &&
    {
        unset TNSPEC_SET;      unset TNSPEC_SET_JSON
        unset TNSPEC_SET_HW;   unset TNSPEC_SET_HW_JSON
        unset TNSPEC_SET_SW;   unset TNSPEC_SET_SW_JSON
        unset TNSPEC_SET_BASE; unset TNSPEC_SET_BASE_JSON
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
        pr_warn   "  Use of internal environment variables detected."
        pr_err    "      TNSPEC_SET_* CANNOT BE SET EXTERNALLY."
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
    }
}

tnspec_check_options() {
    # Incompatible options
    [ -n "$_diags" ] || [ -n "$_modem" ] ||
    [ -n "$_fused" ] || [ -n "$_battery" ] ||
    [ -n "$_watchdog" ] || [ -n "$_erase_all_partitions" ] &&
    {
        unset _fused
        pr_info ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
        pr_warn_b "  USE OF UNSUPPORTED OPTIONS DETECTED."
        pr_info   ""
        pr_info_b "  Unsupported options: -z, -e, -m, -f, -b, -w"
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info ""
    }
}

tnspec_read_cid() {
    local ecid
    if [ "$_dryrun" == "1" ]; then
        ecid=0x${DRYRUN_FUSE:-1}0000001deadbeefec1dface12345678
    else
        # sets "ecid" and "skip_uid"
        if [ "$flash_driver" == "tegraflash" ]; then
            ecid=$($(nvbin $(getprop tegrarcm)) $instance --uid | grep BR_CID | cut -d' ' -f2)
        else
            # Assume nvflash
            ecid=$($(nvbin nvflash) $instance --cid | grep BR_CID | cut -d' ' -f2)
        fi
        skip_uid=1
    fi

    ecid=${ecid:2}
    [ "${#ecid}" != "32" ] && {
        pr_err "failed to read CID. Is your device in recovery mode?" "tnspec_read_cid: "
        exit 1
    }
    rcm_mode=${ecid:0:7}
    local fused=${ecid:0:1}
    local fused_string="UNKNOWN"
    case $fused in
        1) fused_string="[UNFUSED] Preproduction Mode"
           ;;
        3) fused_string="[UNFUSED] NvProduction Mode"
           ;;
        5) fused_string="[FUSED] Secure SBK Mode"
           _fused=1
           ;;
        6) fused_string="[FUSED] Secure PKC Mode"
           _fused=1
           ;;
        *) fused_string="[UNKNOWN] PLEASE CHECK YOUR DEVICE."
           fused=0
           ;;
    esac
    pr_info_b "$fused_string" "FUSED: "
    [ "$fused" == "0" ] && {
        pr_err "RCM_VERSION [$rcm_mode] doesn't seem valid. Please check your device." \
               "tnspec_read_cid: "
        [ -z "$_force" ] && {
            pr_warn "(or use -F option to ignore this error)"
            exit 1
        }
    }
    cid=${ecid:7}
    chipid=$(echo -n "$cid" | sha256sum | cut -f1 -d' ')
    chipid=${chipid:0:32}
    pr_info_b "$cid" "CHIP_ID: "
    pr_info_b "$chipid [HASHED]" "CHIP_ID: "

    [ "$_verbose" == "1" ] && {
        pr_info_b "$rcm_mode" "RCM: "
        pr_info_b "$rcm_mode$cid" "ECID: "
        local converted=$(_format_chip_id "$ecid" '000000')
        pr_info_b "$converted" "CHIP_ID (reversed): "
    }
}

tnspec_init_workspace() {
    local p=${TNSPEC_WORKSPACE:-$HOME/.tnspec}
    # Show error only if directory exists
    [ -d "$p" ] && [ ! -O "$p" ] && {
        pr_err "Terminating as $p is not owned by $USER" "tnspec_init_workspace: "
        exit 1
    }
    workspace=$p/$cid
    [[ $workspace =~ ' ' ]] && {
        pr_err "TNSPEC Workspace cannot contain spaces. (Current workspace: '$p')" "tnspec_init_workspace: "
        pr_err "You can use TNSPEC_WORKSPACE to override the current workspace." "tnspec_init_workspace: "
        exit 1
    }
    [ ! -d "$workspace" ] && {
        mkdir -p $workspace || {
            pr_err "Failed to create workspace directory $workspace" "tnspec_init_workspace: "
            exit 1
        }
    }
    [ -z "$(flash_status)" ] && flash_status "initialized"

    pr_info "$workspace" "TNSPEC_WORKSPACE: "
}

tnspec_cmd_factory() {
    local flash_post=()

    # Add data for factory mode only
    if [ "$origin" == "factory" ]; then
        update_tnspec="${update_tnspec:+$update_tnspec;}factory.date=$(date '+%F %T %Z')"
    fi

    [ "$_verbose" == "1" ] && pr_info_b "$update_tnspec" "$MODE: "

    # Select flash target when 'origin' is 'factory' or 'recovery_hw'
    # Skip when it's 'recovery'
    if [ "$origin" != "recovery" ]; then
        if [ -z "$board" ]; then
            local family=$(tnspec spec get family)
            local boards=$(tnspec spec list all -g hw)
            _cl="1;4;" pr_ok_bl "Supported HW List for $family" "$MODE: "
            tnspec spec list -v -g hw

            [ "$origin" == "recovery_hw" ] && [ -n "$tnspec_source" ] && {
                local _tnsid="$(_tnspec spec get id < $tnspec_source).$(_tnspec spec get config < $tnspec_source)"
                [ "$_tnsid" != "." ] && {
                    pr_info ""
                    _cl="1;4;" pr_cyan "COMPATIBLE TARGETS FOR THIS DEVICE [$_tnsid]"
                    pr_warn "NOTE:"
                    pr_warn "Choose one of the following only if you need to refresh HW spec for the current device."
                    pr_warn "e.g. HW spec has been changed since last flashed."
                    pr_warn "--"
                    tnspec spec list $_tnsid -v -g hw
                    pr_info ""
                }
            }
            _choose_hook=_choose_hook_flash_core _choose "$MODE MODE >> " "$boards" board
        else
            # check if board overrides "config"
            [[ $board =~ : ]] && {
                tnspecid_config_override="${board#*:}"
                board="${board%%:*}"
            }
        fi
    fi

    # Print the new "config"
    [ -n "$tnspecid_config_override" ] && {
       pr_info_b "Overriding 'config' of '$board' => '$tnspecid_config_override'" "config_override: "
    }

    factory_set_sn
    factory_set_macs
    factory_set_partitions

    # Set up nct. When origin is 'recovery', NCT will be initialized using the
    # pre-loaded tnspec ($tnspec_source)
    [ "$origin" != "recovery" ] &&
        tnspec_setup $nctbin board $board ||
        tnspec_setup $nctbin tnspec $tnspec_source

    # Update
    nct_update $nctbin $nctbin.updated VAL "$update_tnspec"
    nct_diff $nctbin $nctbin.updated || cp $nctbin.updated $nctbin

    # register tnspec before flashing
    _tnspec nct dump tnspec -n $nctbin > $nctbin.tnspec && {
        db_tnspec_register $nctbin.tnspec
        db_tnspec_generate_nct $nctbin || exit 1
    } || {
        pr_err "Error while generating TNSPEC." "$MODE: "
        exit 1
    }

    # Print the final NCT
    _tnspec nct dump -n $nctbin

    run_flash || {
        pr_err_b "[ERROR] Flashing failed." "run_flash factory/recovery: "
        exit 1
    }
}

factory_set_sn() {
    # SERIAL NUMBER
    [ "$BOARD_SN" == "" ] && {
        pr_info_b "[SN]" "$MODE: "
        pr_err "BOARD_SN is not set." "$MODE: "

        [ "$_unattended" != "1" ] && {
            read -p "ENTER SERIAL NUMBER >> " BOARD_SN
        }
    }
    [ -n "$BOARD_SN" ] && {
        update_tnspec="${update_tnspec:+$update_tnspec;}sn=$BOARD_SN"
        pr_ok_b "SN: $BOARD_SN" "$MODE: "
    } || pr_err_b "SN: (missing)" "$MODE: "
}

factory_set_macs() {
    local mac_types="wifi bt eth" skip_type="eth"
    local mac menv t show_help=1

    declare -A mac_envs mac_descs
    mac_envs[wifi]=BOARD_WIFI; mac_descs[wifi]="Wifi"
    mac_envs[bt]=BOARD_BT; mac_descs[bt]="Bluetooth"
    mac_envs[eth]=BOARD_ETH; mac_descs[eth]="Ethernet"

    for t in $mac_types; do
        menv=${mac_envs[$t]}
        eval mac=\"\$$menv\"
        pr_info_b "[MAC - ${mac_descs[$t]}]" "$MODE: "
        [ "$mac" == "" ] && {
            pr_err "$menv is not set." "$MODE: "

            [ "$_unattended" != "1" ] && ! _in_array $t $skip_type && {
                pr_info "ENTER MAC ADDRESS For '${mac_descs[$t]}' (Hit Enter to Skip)" "$MODE: "
                if [ "$show_help" == "1" ]; then
                    show_help=0
                    pr_info ""
                    pr_info__ "Supported MAC Address Formats"
                    pr_info "AA:BB:CC:DD:EE:FF" "· "
                    pr_info "AA-BB-CC-DD-EE-FF" "· "
                    pr_info "AABBCCDDEEFF" "· "
                    pr_info ""
                fi
                while :; do
                    read -p "MAC[$t] >> " $menv
                    eval mac=\"\$$menv\"
                    mac=$(_validate_mac "$mac") && break ||
                        pr_err "MAC[$t] '$mac' is not valid." "$MODE: "
                done
            }
        }
        [ -n "$mac" ] && {
            # Re-validate MAC addresses directly set in environment variables.
            mac=$(_validate_mac "$mac") || {
                pr_err "MAC[$t] '$mac' is not valid." "$MODE: "
                exit 1
            }
            update_tnspec="${update_tnspec:+$update_tnspec;}$t=$mac"
            pr_ok_b "MAC[$t]: $mac" "$MODE: "
        } || pr_warn "MAC[$t] skipped" "$MODE: "
    done
}

_validate_mac() {
python - << EOF
import re
import sys
mac="$1"
if not len(mac):
    sys.exit(0)
m = re.match('^([0-9a-fA-F]{2}[:-]{0,1}){5}[0-9a-fA-F]{2}$',mac)
if m:
    m = m.group(0)
    m = m.upper()
    m = m.replace(':','')
    m = m.replace('-','')
    m = ':'.join([ m[i:i+2] for i in range(0,len(m),2) ])
    print(m)
else:
    print(mac)
    sys.exit(1)
sys.exit(0)
EOF
}

factory_set_partitions() {
    local _path=$PWD
    cd $ROOT_PATH
    pr_info ""
    pr_info_b "[EKS]" "$MODE: "
    [ "$BOARD_EKS" == "" ] && {
        pr_warn "BOARD_EKS is not set." "$MODE: "
        [ "$_fused" != "1" ] &&
            pr_warn "(you're probably okay without it since your device is not fused)"

        [ "$_unattended" != "1" ] && {
            read -p "ENTER EKS FILE PATH (hit ENTER to ignore) >> " BOARD_EKS
            # use eval to expand env variables.
            [ -n "$BOARD_EKS" ] && eval BOARD_EKS=$BOARD_EKS
        }
        [ "$BOARD_EKS" == "" ] && pr_warn "BOARD_EKS ignored." "$MODE: "
    }
    if [ "$BOARD_EKS" != "" ]; then
        [ ! -f "$BOARD_EKS" ] && {
            pr_err_b "[EKS] Not found : $BOARD_EKS" "$MODE: "
            exit 1
        }
        local _eks_org=$BOARD_EKS
        tnspec_lint eks $BOARD_EKS $_path/eks.lint.dat > $TNSPEC_OUTPUT &&
            BOARD_EKS=$_path/eks.lint.dat || {
                pr_err_b "[EKS] Invalid EKS : $BOARD_EKS" "$MODE: "
                exit 1
            }
        tag=eks obj_save $BOARD_EKS
        pr_ok_b "EKS: $BOARD_EKS (linted from $_eks_org)" "$MODE: "
    fi
    pr_info ""

    pr_info_b "[FCT]" "$MODE: "
    [ "$BOARD_FCT" == "" ] && {
        pr_warn "BOARD_FCT is not set." "$MODE: "

        # No manual prompt for FCT (it's almost always skipped)
        false && {
            read -p "ENTER FCT FILE PATH (hit ENTER to ignore) >> " BOARD_FCT
            [ -n "$BOARD_FCT" ] && eval BOARD_FCT=$BOARD_FCT
        }
        [ "$BOARD_FCT" == "" ] && pr_warn "BOARD_FCT ignored." "$MODE: "
    }
    if [ "$BOARD_FCT" != "" ]; then
        [ ! -f "$BOARD_FCT" ] && {
            pr_err_b "[EKS] Not found : $BOARD_FCT" "$MODE: "
            exit 1
        }
        tnspec_lint fct $BOARD_FCT > $TNSPEC_OUTPUT || {
            pr_err_b "[FCT] Invalid FCT : $BOARD_FCT" "$MODE: "
            exit 1
        }

        tag=fct obj_save $BOARD_FCT
        pr_ok_b "FCT: $BOARD_FCT" "$MODE: "
    fi

    # Update flash_post
    local s
    if [ "$BOARD_EKS" != "" ]; then
        s=$(_obj_key $BOARD_EKS)
        update_tnspec="${update_tnspec:+$update_tnspec;}partitions.eks=$s"
        flash_post+=("EKS $BOARD_EKS")
    fi
    if [ "$BOARD_FCT" != "" ]; then
        s=$(_obj_key $BOARD_FCT)
        update_tnspec="${update_tnspec:+$update_tnspec;}partitions.fct=$s"
        flash_post+=("FCT $BOARD_FCT")
    fi
    cd $_path
}

_choose_hook_flash_core() {
    input_hooked=""
    tnspecid_config_override=""
    if [ "$1" == "list" ]; then
        tnspec spec list -v -g hw
    elif [ "$1" == "all" ]; then
        tnspec spec list all -v -g hw
    elif [ "$1" == "env" ]; then
        pr_warn "BOARD_SN='$BOARD_SN'"
        pr_warn "BOARD_EKS='$BOARD_EKS' BOARD_FCT='$BOARD_FCT'"
        pr_warn "BOARD_WIFI='$BOARD_WIFI' BOARD_BT='$BOARD_BT' BOARD_ETH='$BOARD_ETH'"
    elif [ "$1" == "" ]; then
        pr_info "Available Commands:"
        pr_info__ "'all', 'list', 'env'"
    elif [[ $1 =~ : ]]; then
        # if input contains ":", truncate everything after : since string after
        # that is used to override "config"
        input_hooked="${1%%:*}"
        tnspecid_config_override="${1#*:}"
        return 1
    else
        return 1
    fi
    return 0
}

tnspec_cmd_factory_reset() {
    [ "$_unattended" == "1" ] && [ -z "$board" ] && {
        pr_err "BOARD must be set in unattended mode" "recovery: "
        exit 1
    }

    MODE=FACTORY

    pr_err_b "----------------------------------------------"
    pr_err_b "   FACTORY MODE. EVERYTHING WILL BE REMOVED"
    pr_err_b "----------------------------------------------"

    origin=factory tnspec_cmd_factory
}

tnspec_check_registered() {
    tnspec_source=$(server_only=1 db_tnspec_get)
    if [ -z "$tnspec_source" ]; then
        pr_err "$cid not registered." "RECOVERY: "
        tnspec_cmd_register update
        tnspec_source=$(db_tnspec_get)
        [ -z "$tnspec_source" ] && {
            pr_err "Couldn't find TNSPEC from device. factory reset required." "RECOVERY: "
            exit 1
        }
    fi
}
tnspec_cmd_factory_recovery() {
    tnspec_check_registered

    MODE=RECOVERY
    BOARD_SN=${BOARD_SN:-$(_tnspec spec get sn < $tnspec_source)}
    BOARD_WIFI=${BOARD_WIFI:-$(_tnspec spec get wifi < $tnspec_source)}
    BOARD_BT=${BOARD_BT:-$(_tnspec spec get bt < $tnspec_source)}
    BOARD_ETH=${BOARD_ETH:-$(_tnspec spec get eth < $tnspec_source)}
    BOARD_EKS=${BOARD_EKS:-$(db_tnspec_find_obj eks)} || help_missing_obj EKS
    BOARD_FCT=${BOARD_FCT:-$(db_tnspec_find_obj fct)} || help_missing_obj FCT

    origin=recovery

    if [ -z "$board" ]; then
        if [ "$1" == "hw" ]; then
            [ "$_unattended" == "1" ] && {
                pr_err "BOARD must be set for 'recovery hw' in unattended mode" "tnspec_cmd_factory_recovery: "
                exit 1
            }
            local _hw
            pr_info_b "Hit <ENTER> for auto-recovery. Enter 'hw' to choose new board."
            read -p ">> " _hw
            [ "$_hw" == "hw" ] && origin=recovery_hw
        elif [ -n "$1" ]; then
            board="$1"
            origin=recovery_hw
        fi
    else
        # Since $board is already set, origin needs to be updated to
        # "recovery_hw" instead of the default value "manual".
        origin=recovery_hw
    fi
    tnspec_cmd_factory
}

tnspec_cmd_tnspec() {
    if [ "$_unattended" == "1" ] && [ -z "$BOARD_UPDATE" ] && [ -z "$BOARD_UPDATE_JSON" ] ; then
        pr_err_b "BOARD_UPDATE[_JSON] not set for unattended mode." "UPDATE: "
        exit 1
    fi

    local _tns=nct.device.tnspec
    pr_info "Reading TNSPEC..." "UPDATE: "

    [ "$_dryrun" == "1" ] && {
        local tmp=$(db_tnspec_get)
        [ -z "$tmp" ] && { pr_err "TNSPEC not found."; return 1; }
        _su rm $_tns 2> /dev/null
        cp $tmp $_tns
        cp $_tns $_tns.updated
        _tnspec nct new -o nct.device <  $_tns.updated
    } || {
        nct_read nct.device && cp nct.device nct.device.org
        nct_upgrade_tnspec nct.device &&
        __tnspec nct dump tnspec -n nct.device.org > $_tns 2> $TNSPEC_OUTPUT &&
        __tnspec nct dump tnspec -n nct.device > $_tns.updated || {
            pr_err "TNSPEC not found. 'recovery' or 'factory' needed" "UPDATE: " >&2
            exit 1
        }
    }

    local p="set | sync_db | revert | view [pending] | diff | save/register [force] | quit"

    if [ -n "$BOARD_UPDATE" ] || [ -n "$BOARD_UPDATE_JSON" ] ; then
        # modify NCT directly
        nct_update nct.device nct.device.updated VAR BOARD_UPDATE
        nct_diff nct.device nct.device.updated &&
            pr_info_b "[BOARD_UPDATE] Nothing to update." "UPDATE: " || {
            _tnspec nct dump tnspec -n nct.device.updated > $_tns.updated
            [ "$1" == "register" ] && {
                _tnspec_cmd_tnspec_register $_tns.updated nct.device.updated
            }
            pr_warn "Updating.." "UPDATE: "
            nct_write nct.device.updated
            pr_ok_b "[BOARD_UPDATE] TNSPEC has been updated." "UPDATE: "
        }
    else
        # interactive mode
        local c _update
        cp $_tns $_tns.tmp
        while true; do
            pr_info_b "$p"
            read -p ">> " c
            eval local _c=("$c")
            local a=${_c[@]:1}
            local C=${_c[0]}
            case $C in
                set)
                    _update="$a"
                    TNSPEC_SET_BASE=$_update _tnspec spec get < $_tns.tmp > $_tns.updated
                    cp $_tns.updated $_tns.tmp
                    diff -u $_tns $_tns.updated
                    ;;
                sync_db)
                    local db="$(server_only=1 db_tnspec_get)"
                    [ -n "$db" ] && {
                        cp $db $_tns.updated
                        cp $_tns.updated $_tns.tmp
                    } || pr_err "Couldn't load TNSPEC from DB" "tnspec: "
                    diff -u $_tns $_tns.updated
                    ;;
                revert)
                    cp $_tns $_tns.tmp
                    cp $_tns $_tns.updated
                    ;;
                view)
                    [ "$a" == "pending" ] &&
                        _tnspec spec get < $_tns.updated ||
                        _tnspec spec get < $_tns
                    ;;
                diff)
                    diff -u $_tns $_tns.updated
                    ;;
                save|register)
                    if [ "$a" != "force" ] && diff -u $_tns $_tns.updated; then
                        pr_info "[tnspec] Nothing to update." "UPDATE: "
                    else
                        _tnspec nct new -o nct.device.updated <  $_tns.updated
                        [ "$C" == "register" ] && {
                            _tnspec_cmd_tnspec_register $_tns.updated nct.device.updated
                        }
                        [ "$_dryrun" == "1" ] && break
                        pr_warn "Updating.." "UPDATE: "
                        nct_write nct.device.updated
                        pr_ok_b "[tnspec] TNSPEC has been updated." "UPDATE: "
                        break
                    fi
                    ;;
                quit)
                    break
                    ;;
            esac
        done
        rm $_tns.tmp
    fi
    [ "$_dryrun" == "1" ]  && return 0
    _reboot
}

_tnspec_cmd_tnspec_register() {
    local tns="$1"
    local tns_nct="$2"
    pr_cyan "[tnspec] registering..." "TNSPEC_SERVER: "
    [ -e "$tns_nct.org" ] && [ ! -w "$tns_nct.org" ] && _su rm $tns_nct.org
    cp $tns_nct $tns_nct.org || exit 1
    origin=tnspec_cmd db_tnspec_register $tns
    # Generate a new NCT using TNSPEC from the server
    db_tnspec_generate_nct $tns_nct || exit 1
    nct_diff $tns_nct.org $tns_nct && pr_info "[tnspec] TNSPEC unchanged." "TNSPEC_SERVER: "
}

tnspec_cmd_auto() {
    local status=$(cat $workspace/status)
    [ "$status" == "aborted" ] || [ "$status" == "flashing" ] && {
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        pr_err_b " FLASHING ABORTED PREVIOUSLY. Forcing 'RECOVERY'"
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        tnspec_cmd_factory_recovery
        return
    }
    tnspec_check_registered

    # Will be set by tnspec_setup
    local flash_method

    tnspec_setup $nctbin "$@"

    local flash_post _eks _fct
    _eks=$(db_tnspec_find_obj eks) || help_missing_obj EKS
    [ -n "$_eks" ] && flash_post+=("EKS $_eks")
    _fct=$(db_tnspec_find_obj fct) || help_missing_obj FCT
    [ -n "$_fct" ] && flash_post+=("FCT $_fct")

    _tnspec nct dump -n $nctbin

    # locally register tnspec before flashing
    # NOTE: it it important that we don't register tnspec to server when 'auto' is used.
    #       'register'-class commands must be explicitly used to update to the server.
    _tnspec nct dump tnspec -n $nctbin > $nctbin.tnspec &&
        local_only=1 db_tnspec_register $nctbin.tnspec

    if [ -z "$flash_method" ]; then
        run_flash || {
            pr_err_b "[ERROR] Flashing failed." "run_flash auto/manual: "
            exit 1
        }
    else
        run_flash_alternate $specid $flash_method
    fi
}

tnspec_cmd_register() {
    local update="$1"
    local _tns=nct.device.tnspec

    pr_info "Reading TNSPEC" "REGISTER: "
    nct_read nct.device && nct_upgrade_tnspec nct.device &&
        __tnspec nct dump tnspec -n nct.device > $_tns || {
            pr_err "TNSPEC not found. Please try 'recovery' or 'factory' command." "REGISTER: " >&2
            exit 1
        }
    local _tns_id="$(_tnspec spec get id < $_tns).$(_tnspec spec get config < $_tns)"
    [ -z "$_tns_id" ] && {
        pr_err "TNSPEC not found. Please try 'recovery' or 'factory' command." "REGISTER: " >&2
        exit 1
    }

    local s
    pr_info "[EKS] Reading..." "REGISTER: "
    [ -e eks.device ] && _su rm -f eks.device 2> /dev/null
    part_read EKS eks.device && tnspec_lint eks eks.device eks.device.lint > $TNSPEC_OUTPUT && {
        pr_info_b "[EKS] Validated." "REGISTER: "
        s=$(_obj_key eks.device.lint)
        TNSPEC_SET_BASE="partitions.eks=$s" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
        tag=eks obj_save eks.device.lint
    } || {
        # FIXME: terminate if it's production mode
        pr_err "[EKS] invalid EKS partition. Ignored." "REGISTER: "
        TNSPEC_SET_BASE="partitions.eks=-" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
    }

    pr_info "[FCT] Reading..." "REGISTER: "
    part_read FCT fct.device && tnspec_lint fct fct.device > $TNSPEC_OUTPUT && {
        pr_info_b "[FCT] Validated." "REGISTER: "
        s=$(_obj_key fct.device)
        TNSPEC_SET_BASE="partitions.fct=$s" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
        tag=fct obj_save fct.device
    } || {
        # FIXME: terminate if it's production mode
        pr_err "[FCT] invalid FCT partition. Ignored." "REGISTER: "
        TNSPEC_SET_BASE="partitions.fct=-" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
    }

    origin=device db_tnspec_register $_tns

    [ "$update" == "update" ] && {
        db_tnspec_generate_nct nct.device.reg || exit 1
        nct_write nct.device.reg || {
            pr_err "Failed to write TNSPEC to device." "REGISTER: " >&2
            exit 1
        }
    }
}

tnspec_lint() {
    local partition="$1"; shift
    if [ "$partition" == "eks" ]; then
        _tnspec_lint_eks "$@"
    elif [ "$partition" == "fct" ]; then
        _tnspec_lint_fct "$@"
    fi
}

_tnspec_lint_eks() {
python - << EOF
import struct
import zlib
import sys

src = "$1"
dst = "$2"

with open(src,'r') as f:
    data = f.read()
    size = struct.unpack('i',data[:4])[0]
    _data = data[4:]
    if len(_data) < size:
        print("tnspec_lint_eks: File size too small.")
        sys.exit(1)
    if _data[:6] != 'NVEKSP':
        print("tnspec_lint_eks: Magic HDR not found.")
        sys.exit(1)
    _data = data[:size+4]
    if zlib.crc32(_data[4:-4]) != struct.unpack('i',_data[-4:])[0]:
        print("tnspec_lint_eks: CRC32 mismatch")
        sys.exit(1)
if dst:
    with open(dst,'w') as f:
        f.write(_data)

sys.exit(0)
EOF
}

_tnspec_lint_fct() {
python - << EOF
import sys
import struct
with open("$1", 'r') as f:
    x = f.read()
    if len(x) < 1082:
        print("tnspec_lint_fct: can't find superblock for ext4.")
        sys.exit(1)
    if struct.unpack('H',x[1080:1082])[0] != 0xef53:
        print("tnspec_lint_fct: ext4 magic number not found.")
        sys.exit(1)
sys.exit(0)
EOF
}

_format_chip_id() {
python - << EOF
cid="$1"
padding="$2"
cid = [ cid[i:i+2] for i in range(0,len(cid),2) ][::-1]
print(''.join(cid)[:-len(padding)] + padding)
EOF
}

###############################################################################
# TNSPEC Registration/Fetch
###############################################################################
db_tnspec_register() {
    local file="$1"

    # Update registration information

    # TODO: get real user information
    local reg_info
    reg_info="registered.origin=${origin:-manual}"
    reg_info="$reg_info;registered.user=$USER@$HOSTNAME"
    reg_info="$reg_info;rcm_mode=$rcm_mode;chipid=$chipid"
    reg_info="$reg_info;meta=-;revision=-;signature=-"
    TNSPEC_SET_BASE="$reg_info" _tnspec spec get < $file > $file.updated
    cp $file.updated $file

    # Add TNSPEC signature
    reg_info="signature=$(_obj_key $file)"
    TNSPEC_SET_BASE="$reg_info" _tnspec spec get < $file > $file.updated
    cp $file.updated $file

    tag=_tnspec _obj_save "$file" tnspec.local

    [ "$local_only" == "1" ] && return 0

    [ "$tns_online" == "1" ] && {
        local params="$tnspec_server/tnspec/$cid?user=$USER@$HOSTNAME&type=dev"
        local res=$(curl -ks -m 10 -X POST -H "Content-Type: application/json" -d@$workspace/tnspec.local "$params")
        server_return "$res" && _db_tnspec_get tnspec_server.json && {
            tag=tnspec _obj_save tnspec_server.json tnspec
            rm tnspec_server.json
            pr_cyan "registered to server." "tnspec_register: "
        } || {
            pr_err "failed to register to server." "tnspec_register: "
            [ -z "$_force" ] && {
                pr_info "Flash with '-F' option to ignore this error."
                exit 1
            } ||  return 1
        }
    }
}

db_tnspec_get() {
    # always try to get the latest tnspec
    if [ "$tns_online" == "1" ];then
        _db_tnspec_get tnspec_server.json && {
            # ignore tag to skip logging
            _obj_save tnspec_server.json tnspec
            echo "$workspace/tnspec"
            return
        }
    fi

    [ "$tns_online" == "1" ] && [ "$server_only" == "1" ] && return

    # try tnspec.local
    [ -f "$workspace/tnspec.local" ] && {
        echo "$workspace/tnspec.local"
        return
    }

    # otherwise, use cached tnspec if found.
    [ -f "$workspace/tnspec" ] && {
        echo "$workspace/tnspec"
        return
    }

    # unregistered device
}

_db_tnspec_get() {
    local target="$1"
    local params="$tnspec_server/tnspec/$cid?user=$USER@$HOSTNAME"
    curl -ks -m 30 "$params" > $target.tmp &&
        _tnspec spec get < $target.tmp > $target &&
        [ "$(_tnspec spec get chipid < $target)" != "" ] && {
            rm $target.tmp
            return 0
        }
    pr_warn "Could not find TNSPEC from server." "_db_tnspec_get: " >&2
    return 1
}

db_tnspec_find_obj() {
    local t="$1"
    local tns="$(db_tnspec_get)"
    [ -z "$tns" ] && return 1

    local key="$(_tnspec spec get partitions.$t < $tns)"
    [ "$key" == "" ] && return 0
    tag=$t obj_get $key && return 0 || return 1
}

# Generate NCT from the latest tnspec
db_tnspec_generate_nct() {
    local target_nct="$1"
    local tns=$(db_tnspec_get)
    [ -z "$tns" ] && {
        pr_err "TNSPEC is not found" "db_tnspec_generate_nct: " >&2
        return 1
    }
    _tnspec nct new -o $target_nct < $tns || {
        pr_err "Failed to generate NCT" "db_tnspec_generate_nct: " >&2
        return 1
    }
}
###############################################################################
# TNSPEC Server Manager
###############################################################################
server_init() {
    [ "$_offline" == "1" ] && {
        pr_warn "** OFFLINE MODE **" "TNSPEC_SERVER: "
        return
    }
    # Check if tnspec server is online
    local res="$(curl -sk -m 5 $tnspec_server 2> $TNSPEC_OUTPUT)"
    [ "$res" == "tnspec server" ] && {
        tns_online=1
        pr_cyan_b "$tnspec_server [ONLINE]" "TNSPEC_SERVER: "
    } || pr_err_b "$tnspec_server [OFFLINE]" "TNSPEC_SERVER: "
}

server_return() {
    local s="$1"
    local code="${s%%:*}"
    [[ $s =~ : ]] && {
        local msg="${s#*:}"
        [ "$code" == "OK" ] &&
            pr_cyan_b "[OK] $msg" "TNSPEC_SERVER: " ||
            pr_err_b "[ERROR] $msg" "TNSPEC_SERVER: "
    }

    [ "$code" == "OK" ] && return 0 || return 1
}

###############################################################################
# OBJ Manager
###############################################################################

obj_init() {
    [ -f "$workspace/logs" ] && {
        local lineno=$(wc -l < $workspace/logs)
        if [ "$lineno" -gt "1000" ]; then
            mv -f $workspace/logs $workspace/logs.old
        fi
    }
    ws=$workspace/o
    [ ! -d "$ws" ] && mkdir -p $ws
}

# obj_save <file>
obj_save() {
    local file="$1"

    _obj_save "$file"

    [ "$tns_online" != "1" ] && {
        pr_warn "TNSPEC Server is OFFLINE. OBJ[$(_obj_key $file)] not uploaded." "obj_save: "
        return
    }

    local k=$(_obj_key "$file")
    local o_status="$(_obj_status_sync $k)"

    if [ "$o_status" == "notfound" ]; then
        gzip < "$file" > $k.gz
        local params="$tnspec_server/o?o=$k&type=$tag&user=$USER@$HOSTNAME"
        local result=$(curl -ks -X POST -F file=@$k.gz "$params")
        server_return "$result" && pr_info "[$k] saved to server." "obj_save: " ||
                                   pr_err "[$k] wasn't saved to server." "obj_save: "
        rm $k.gz
    fi
}

# _obj_save <file> [symlink]
_obj_save() {
    local file="$1"
    local sym="$2"

    [ ! -f "$file" ] && {
        pr_err "'$file' not found." "_obj_save: "
        exit 1
    }
    local k=$(_obj_key "$file")
    local obj=$ws/$k
    [ ! -f "$obj" ] && cp "$file" "$obj"

    # Create a (relative) symlink when requested.
    [ -n "$sym" ] && ln -sf o/$k $workspace/$sym

    [ -n "$tag" ] && tnspec_logger $tag $k
}

# obj_get <key>
# returns <obj>
obj_get() {
    [ -z "$1" ] && return

    local k="$1"
    local path="$(_obj_get $k)"

    [ -n "$path" ] && {
        echo "$path"
        # Check if tnspec server has this resource. If not, save it.
        [ "$tns_online" == "1" ] && [ "$(_obj_status_sync $k)" == "notfound" ] && {
            pr_info "Found object [$k] locally, but missing in server. Uploading..." "obj_get: " >&2
            obj_save $path >&2
        }
        return 0
    }

    [ "$tns_online" != "1" ] && {
        pr_err "TNSPEC Server is offline. Couldn't find object [$k]." "obj_get: " >&2
        return 1
    }

    local o_status="$(_obj_status_sync $k)"

    if [ "$o_status" == "notfound" ]; then
        pr_err "[$k] not found." "obj_get: " >&2
        return 1
    elif [ "$o_status" == "pending" ]; then
        pr_err "[$k] is being prepared. Try again in a few minutes." "obj_get: " >&2
        return 1
    elif [ "$o_status" == "ready" ]; then
        pr_cyan "[$k] dowloading..." "obj_get: " >&2
        local params="$tnspec_server/o/$k?user=$USER@$HOSTNAME"
        curl -ks -m 60 "$params" > $k.gz &&
            gunzip $k.gz && _obj_save $k &&
            rm $k && pr_cyan "[$k] complete" "obj_get: " >&2 || {
                pr_err "ERROR while getting data" "obj_get: " >&2
                return 1
            }
    else
        pr_err "Unkown Error" "obj_get: " >&2
        pr_info "-----------------" >&2
        pr_warn "$o_status" >&2
        pr_info "-----------------" >&2
        return 1
    fi
    echo "$(_obj_get $k)"
}
_obj_get() {
    [ ! -f "$ws/$1" ] && return 1
    echo "$ws/$1"
}
_obj_key() {
    echo $(sha256sum "$1" | cut -f1 -d' ')
}
_obj_status_sync() {
    [ "$tns_online" != "1" ] && {
        pr_err "server is offline" "_obj_status_sync: " >&2
        echo "server offline"
        return 1
    }
    local o_status=$ws/$1.status
    if [ ! -f "$o_status" ] || [ "$(cat $o_status)" != "ready" ]; then
        curl -ks -m 5 $tnspec_server/o/$k?status > $o_status
    fi
    echo "$(cat $o_status)"
}

# Logger
tnspec_logger() {
    printf "[%s] %-8s %s\n" "$(date)" "$1" "$2" >> $workspace/logs
}

###############################################################################
# OLD FLASH MAIN
###############################################################################
flash_main_legacy() {
    nctbin=nct.bin

    [ "$_fused" == "1" ] && {
        pr_err "[Flashing FUSED devices]" "fused: "
    }

    check_tools_nvidia

    if [ -n "$settings" ] && [ "$_unattended" == "1" ]; then
        board=${board:-$(getprop default_board)}
    fi

    [ "$flash_driver" == "tegraflash" ] && {
        pr_err "tegraflash is not supported in the legacy interface." "flash_main_legacy: "
        exit 1
    }

    local boards=$(tnspec spec list all -g hw)
    if [ -z "$board" ] && [ "$_unattended" != "1" ] ; then
        local family=$(tnspec spec get family)
        _cl="1;4;" pr_ok_bl "Supported HW List for $family" "TNSPEC: "
        pr_warn "Choose \"auto\" to automatically detect HW" "TNSPEC: "
        tnspec spec list -v -g hw
        pr_info ""
        pr_info_b "'help' - usage, 'list' - list frequently used, 'all' - list all supported"
        board_default=${board_default:-auto}
        _cl="1;" pr_ok "[Press Enter to choose \"$board_default\"]"
        _choose_hook=_choose_hook_flash_main_legacy \
            _choose "DEFAULT:\"$board_default\" >> " "auto $boards" board
    else
        board=${board:-auto}
    fi

    [ "$board" == "auto" ] &&
        tnspec_setup $nctbin auto ||
        tnspec_setup $nctbin board $board

    run_flash || {
        pr_err_b "[ERROR] Flashing failed." "run_flash legacy: "
        exit 1
    }
}

_choose_hook_flash_main_legacy() {
    input_hooked=""
    if [ "$1" == "help" ]; then
        usage
        _cl="1;4;" pr_ok "Available Commands:"
        pr_info_b "'help', 'all', 'list'"
    elif [ "$1" == "list" ]; then
        tnspec spec list -v -g hw
    elif [ "$1" == "all" ]; then
        tnspec spec list all -v -g hw
    elif [ "$1" == "" ]; then
        [[ -n "$board_default" ]] && {
            pr_warn "Trying the default \"$board_default\"" "TNSPEC: "
            input_hooked=$board_default
            query_hooked=">> "

            # board_default is used only once.
            board_default=""
            return 1
        } || pr_err "You need to enter something." "selection: "
    else
        return 1
    fi
    return 0
}

run_flash() {
    local _run_flash_post=0

    _set_cmdline

    pr_info_b "====================================================================="
    pr_info__ "PRODUCT_OUT"
    echo "$PRODUCT_OUT"
    pr_info ""
    pr_info__ "FLASH COMMAND (Run from $PRODUCT_OUT)"
    echo "${cmdline[*]}"
    if [ "${#cmdline_post[@]}" != "0" ]; then
        pr_info ""
        pr_info__ "POST FLASH COMMAND (Run from $PRODUCT_OUT)"
        echo "${cmdline_post[*]}"
        _run_flash_post=1
    fi
    pr_info_b "====================================================================="


    # return if dryrun is set
    [ "$_dryrun" == "1" ] && {
        flash_status "completed"
        return
    }

    flash_status "flashing"

    # Execute command
    eval ${cmdline[@]} || {
        flash_status "aborted"
        return 1
    }

    [ "$_run_flash_post" == "1" ] && {
        eval ${cmdline_post[@]} || {
            flash_status "aborted"
            return 1
        }
    }

    flash_status "completed"
    return 0
}

run_flash_alternate() {
    local tns="$1"
    local method="$2"

    local flash_ops="update_partitions update_nct"
    local op

    pr_info_b "··················································"
    pr_info_b "FLASHING METHOD: $method"
    pr_info_b "··················································"
    for op in $flash_ops; do
        local part file _v v="$(tnspec_get_sw $tns.$method.$op)"
        pr_cyan_b "▮ PROCESSING '$op'"
        case $op in
            update_partitions)
                for _v in $v; do
                    part=${_v%:*}
                    file=${_v#*:}
                    [ -n "$file" ] && file="$(tnspec_get_sw $specid.$file)"
                    [ -z "$file" ] &&
                    {
                        pr_err "[$part] Ignored (missing file)" "  ▸ "
                        continue
                    }
                    [ -f "$file" ] ||
                    {
                        # It's a critical error when the file name is defined,
                        # but doesn't exist.
                        pr_err "[$part] Aborted ('$file' doesn't exist)" "  ▸ "
                        exit 1
                    }
                    pr_info   "[$part] Flashing '$file'" "  ▸ "
                    [ "$_dryrun" == "1" ] &&
                        pr_info "part_write $part $file" "--- " || {
                            part_write $part $file || {
                                pr_err_b "[$part] Failed."  "  ▸ "
                                exit 1
                            }
                        }

                    pr_info_b "[$part] OK!"  "  ▸ "
                done
                ;;
            update_nct)
                [ "$v" != "false" ] && {
                    pr_info   "[NCT] Flashing '$nctbin'" "  ▸ "
                    [ "$_dryrun" == "1" ] && pr_info "nct_write $nctbin" "--- " ||
                                             nct_write $nctbin
                    pr_info_b "[NCT] OK!"  "  ▸ "
                } || pr_info "[NCT] Skipped" "  ▸ "
                ;;
        esac
    done
    pr_cyan_b "▮ DONE! Rebooting your device."
    [ "$_dryrun" != "1" ] && _reboot
    pr_info_b "··················································"
}

###############################################################################
# Partition Read/Write Functions
###############################################################################
part_read() {
    local p=$1 f=$2
    [ -e "$f" ] && _su rm -f $f 2> /dev/null
    [ -e "$f.tmp" ] && _su rm -f $f.tmp 2> /dev/null

    [ "$flash_driver" == "tegraflash" ] && {
        _tegraflash "read $p $f.tmp" > $TNSPEC_OUTPUT || return 1
    } || {
        _nvflash  "--read $p $f.tmp" > $TNSPEC_OUTPUT || return 1
    }
    cp $f.tmp $f || return 1
    _su rm $f.tmp
}

part_write() {
    local p=$1 f=$2
    [ -e "$f" ] || {
        pr_err "'$f' doesn't exist." "part_write: "
        exit 1
    }

    [ "$flash_driver" == "tegraflash" ] && {
        _tegraflash "write $p $f" > $TNSPEC_OUTPUT || return 1
    } || {
        _nvflash "--download $p $f" > $TNSPEC_OUTPUT || return 1
    }
}

###############################################################################
# Flashing Status
###############################################################################
flash_status() {
    [ "$flash_interface" == "legacy" ] || [ -z "$workspace" ] && return

    # Return status if no argument is passed
    if [ "$#" == "0" ]; then
        [ -e "$workspace/status" ] && cat $workspace/status || echo ""
        return
    fi
    echo "$1" > $workspace/status
}

###############################################################################
# Utility functions
###############################################################################

# Test if we have a connected output terminal
_shell_is_interactive() { tty -s ; return $? ; }

# Test if string ($1) is found in array ($2)
_in_array() {
    local hay needle=$1 ; shift
    for hay; do [[ $hay == $needle ]] && return 0 ; done
    return 1
}

# Display prompt and loop until valid input is given
_choose() {
    _shell_is_interactive || { "error: _choose needs an interactive shell" ; exit 2 ; }
    local query="$1"                   # $1: Prompt text
    local -a choices=($2)              # $2: Valid input values
    local _input
    local selected=''
    while [[ -z $selected ]] ; do
        read -p "$query" _input
        [ -n "$_choose_hook" ] && $_choose_hook $_input || {
            _input=${input_hooked:-$_input}

            if ! _in_array "$_input" "${choices[@]}"; then
                pr_err "'$_input' is not a valid choice." "selection: "
            else
                selected=$_input
            fi
        }
        query=${query_hooked:-$query}
    done
    eval "$3=$selected"
    # If predefined input is invalid, return error
    _in_array "$selected" "${choices[@]}"
}

# XXX: There shouldn't be a function for every ODM bit. Remove this.
# Update odmdata watchdog bits
_watchdog_odm() {
    local watchdog=$1
    case $watchdog in
        0|1|2|3)
            odmdata=$(( (odmdata & ~(3 << 16)) | (watchdog << 16) ))
            odmdata=`printf "0x%x" $(( odmdata ))`
            ;;
        *)
            pr_err "Invalid value for option -w. Choose from 0,1,2,3" "_watchdog_odm: " >&2
            exit 1
            ;;
    esac
}

# XXX: There shouldn't be a function for every ODM bit. Remove this.
# Update odmdata power supply bits
_battery_odm() {
    if [[ $1 -eq 1 ]]; then
        odmdata=$(printf "0x%x" $(( odmdata | 1 << 22 )))
    elif [[ $1 -eq 0 ]]; then
        odmdata=$(printf "0x%x" $(( odmdata & ~(1 << 22) )))
    else
        pr_err "Invalid value for option -b. Choose from 0,1" "_battery_odm" >&2
        exit 1
    fi
}

# XXX: There shouldn't be a function for every ODM bit. Remove this.
# Update odmdata regarding required modem:
# select through bits [7:3] of odmdata
# e.g max value is 0x1F
_modem_odm() {
    local modem=$1
    if [[ $modem -lt 0x1F ]]; then
        odmdata=$(( (odmdata & ~(0x1f << 3)) | (modem << 3) ))
        odmdata=`printf "0x%x" $(( odmdata ))`
    else
        pr_warn "Unknown modem reference [$modem]. Unchanged odmdata." "_modem_odm: " >&2
        exit 1
    fi
}

# Pretty prints ($2 - optional header)
pr_info() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}37m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_info_b() {
    _cl="1;" pr_info "$1" "$2"
}
pr_info__() {
    _cl="4;" pr_info "$1" "$2"
}
pr_ok() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}92m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_ok_b() {
    _cl="1;" pr_ok "$1" "$2"
}
pr_ok__() {
    _cl="4;" pr_ok "$1" "$2"
}
pr_ok_bl() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}94m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_cyan() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}96m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_cyan_b() {
    _cl="1;" pr_cyan "$1" "$2"
}
pr_warn() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}93m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_warn_b() {
    _cl="1;" pr_warn "$1" "$2"
}
pr_err() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}91m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_err_b() {
    _cl="1;" pr_err "$1" "$2"
}

nvbin() {
    if [[ -n $_nosudo ]]; then
        echo "$HOST_BIN/$1"
    else
        echo "sudo $HOST_BIN/$1"
    fi
}

_tegraflash() {
    local chip=$(getprop chip) bl=$(getprop bl) applet=$(getprop applet) secure=$(getprop arg_secure)
    local _skip_uid
    [ "$skip_uid" == "1" ] && {
        skip_uid=0
        _skip_uid="--skipuid"
    }
    local params="$_skip_uid --chip $chip --bl $bl --applet $applet $secure"
    local _cmd="$(nvbin tegraflash.py) $params --cmd \"$1\""
    pr_info_b "$_cmd" "_tegraflash: "
    [ "$dumponly" == "1" ] && return 0
    eval "$_cmd"
}

_nvflash() {
    local _resume _skip_uid

    [ "$resume_mode" == "1" ] && {
       _resume="--resume"
    }
    resume_mode=1

    [ "$skip_uid" == "1" ] && {
       _skip_uid="--skipcid"
       skip_uid=0
    }
    local _cmd="$(nvbin nvflash) $_resume $(getprop arg_blob) $@ --bl $(getprop bl) $instance $_skip_uid"
    pr_info_b "$_cmd" "_nvflash: "

    eval "$_cmd"
}

# su
_su() {
    if [[ -n $_nosudo ]]; then
        $@
    else
        sudo $@
    fi
}

# convert unix path to windows path
_os_path()
{
    if [ "$OSTYPE" == "cygwin" ]; then
        echo \'$(cygpath -w $1)\'
    else
        echo $1
    fi
}

# check if we have required tools
check_tools_system()
{
    # system tools
    local tools=(python diff sha256sum wc curl)
    local t missing=()
    for t in ${tools[@]}; do
        if ! $(which $t 2> /dev/null >&2); then
            missing+=("$t")
        fi
    done

    if [[ ${#missing[@]} > 0 ]]; then
        pr_warn "Missing tools: ${missing[*]}"
        if [ "$OSTYPE" == "cygwin" ]; then
            local cygbin=setup-$(uname -m).exe
            pr_info "You're using Cygwin. To install these missing tools, please download $cygbin"
            pr_info "from http://cygwin.com/$cygbin and run"
            pr_info ""
            pr_info "  >> $cygbin -q -P <packages>"
            pr_info ""
            pr_info "To find packages: https://cygwin.com/cgi-bin2/package-grep.cgi"
        fi
        return 1
    fi

    return 0
}

# Check NVIDIA tools
check_tools_nvidia()
{
    local tools t
    if [ "$flash_driver" == "tegraflash" ]; then
        tools="tegraflash.py $(getprop tegradevflash) part_table_ops.py $(getprop tegraracm)"
    else
        tools="nvflash"
    fi
    for t in $tools; do
        [ -x "$HOST_BIN/$t" ] || {
            pr_err "'$HOST_BIN/$t' not found." "check_tools_nvidia: "
            exit 1
        }
    done
}

# Check additional dependencies
check_deps()
{
    local deps d
    if [ "$flash_driver" == "tegraflash" ]; then
        deps="$(getprop bl) $(getprop applet)"
        [ "$(getprop version)" == "2" ] && deps="$deps $(getprop bl_mb2)"
    else
        deps=""
    fi
    for d in $deps; do
        [ -f "$d" ] || {
            pr_err "'$d' not found." "check_deps: "
            exit 1
        }
    done
}

# Set all needed parameters
_set_cmdline_nvflash() {
    # Minimum battery charge required.
    if [[ -n $sw_var_minbatt ]]; then
        pr_err "*** MINIMUM BATTERY CHARGE REQUIRED = $sw_var_minbatt% ***" "_set_cmdline_nvflash: "
        local minbatt="--min_batt $sw_var_minbatt"
    fi

    # Disable display if specified (to prevent flashing failure due to low battery)
    if [[ "$sw_var_no_disp" == "true" ]]; then
        local nodisp="--odm limitedpowermode"
        pr_warn "Display on target is disabled while flashing to save power." "_set_cmdline_nvflash: "
    fi

    # Set ODM data, BCT and CFG files (with fallback defaults)
    local odmdata=${_odmdata:-${sw_var_odm:-"0x9c000"}}
    local bctfile=${sw_var_bct:-"bct.cfg"}
    local cfgfile=${sw_var_cfg:-"flash.cfg"}
    local dtbfile=$sw_var_dtb

    # Set ODM bits
    [[ -n $_modem ]] && _modem_odm $_modem

    # if flashing fused devices, lock bootloader. (bit 13)
    [ "$_fused" == "1" ] && {
        odmdata=$(printf "0x%x" $(( $odmdata | ( 1 << 13 ) )) )
    }

    # Set NCT option
    if [ "$sw_var_skip_nct" != "true" ]; then
        tnspec nct dump nct -n $nctbin > $nctbin.txt
        nct="--nct $nctbin.txt"
    else
        pr_warn "$specid doesn't use NCT." "_set_cmdline_nvflash: "
        nct=""
    fi

    # Set SKU ID, MTS settings. default to empty
    local skuid=${_skuid:-${sw_var_sku:-""}}
    [[ -n $skuid ]] && skuid="-s $skuid"
    [[ -n $sw_var_preboot ]] && local preboot="--preboot $sw_var_preboot"
    [[ -n $sw_var_bootpack ]] && local bootpack="--bootpack $sw_var_bootpack"

    # XXX: remove this. use sw_var_dtb directly
    # Update DTB filename if not previously set.
    # in mobile sanity testing (Bug 1439258)
    if [ -z "$dtbfile" ] && _shell_is_interactive; then
        dtbfile=$(grep dtb ${PRODUCT_OUT}/$cfgfile | cut -d "=" -f 2)
        pr_info "Using the default product dtb file $_dtbfile" "_set_cmdline_nvflash: "
    else
        # Default used in automated sanity testing is "unknown"
        dtbfile=${dtbfile:-"unknown"}
    fi

    cmdline=(
        _nvflash
        $minbatt
        --bct $bctfile
        --setbct
        --odmdata $odmdata
        --configfile $cfgfile
        --dtbfile $dtbfile
        --create
        $skuid
        $nct
        $nodisp
        $preboot
        $bootpack
    )

    [ "$flash_interface" == "legacy" ] || [ "$sw_var_skip_nct" == "true" ] && {
        cmdline=(${cmdline[@]} --go)
        return
    }

    # cmdline_post
    _set_cmdline_xlate_flash_post
    cmdline_post=(_nvflash "--download NCT $nctbin $flash_post --go")
}

# Set all needed parameters for Automotive boards.
_set_cmdline_automotive() {
    # Parse bootburn commandline
    local burnflash_cmd=
    if [ -n "$sw_var_sku" ]; then
        burnflash_cmd="$burnflash_cmd -S $sw_var_sku"
    fi

    if [ -n "$sw_var_dtb" ]; then
        burnflash_cmd="$burnflash_cmd -d $sw_var_dtb"
    fi

    local odmdata=${_odmdata:-${sw_var_odm}}
    if [ -n "$odmdata" ]; then
        burnflash_cmd="$burnflash_cmd -o $odmdata"
    fi

    if [[ $_modem ]]; then
        if [[ $_modem -lt 0x1F ]]; then
            # Set odmdata in bootburn.sh
            burnflash_cmd="$burnflash_cmd -m $_modem"
        else
            pr_warn "Unknown modem reference [$_modem]. Unchanged odmdata." "_mdm_odm: "
        fi
    fi

    cmdline=(
        $PRODUCT_OUT/bootburn.sh
        -a
        -r ram0
        -Z zlib
        $burnflash_cmd
        $instance
        ${commands[@]}
    )
}

_tegraflash_update_partitions() {
    local part file list
    local e

    [ -f "$sw_var_cfg" ] || {
        pr_err "'$sw_var_cfg' is not found." "_tegraflash_update_partitions: "
        exit 1
    }

    [ -n "$sw_var_cfg_override" ] && {
        for e in $sw_var_cfg_override
        do
            part=${e%:*}
            file=${e#*:}

            [ -n "$file" ] && {
                # Check if "file" var is of signed_vars entries.
                _in_array $file $sw_var_signed_vars && {
                    file=($(tnspec_get_sw $specid.$file))
                    [ "${#file[@]}" == "2" ] && {
                        [ "$_fused" == "1" ] && file=${file[1]} || file=${file[0]}
                    }
                } || file=$(tnspec_get_sw $specid.$file)
            }
            list="$list$part:$file "
        done
    }
    [ -n "$list" ] && {
        cp $sw_var_cfg $sw_var_cfg.updated
        pr_info_b "Updating $sw_var_cfg -> $sw_var_cfg.updated" "CFG_PATCH: "
        pr_info "$list" "CFG_PATCH: "
        $(nvbin part_table_ops.py) -i $sw_var_cfg -o $sw_var_cfg.updated $list || {
            pr_err "Failed to patch '$sw_var_cfg' using $list" "CFG_PATCH: " >&2
            exit 1
        }
        sw_var_cfg=$sw_var_cfg.updated
    }
}

_set_cmdline_tegraflash() {
    # Construct cmd
    local cmd

    # Convert flash_post to a command string
    _set_cmdline_xlate_flash_post

    [ "$_fused" != "1" ] && cmd="flash;" || cmd="secureflash;"
    cmd="$cmd $flash_post reboot"

    local skuid=${_skuid:-${sw_var_sku:-""}}
    if [[ -n $skuid && -f fuse_bypass.xml && $_fused -ne 1 ]]; then
        cmd="parse fusebypass fuse_bypass.xml $skuid; $cmd"
        local fbfile="--fb fuse_bypass.bin"
    fi

    if [[ -n $cmd ]]; then
        cmd="--cmd \"$cmd\""
    fi

    local odmdata=${_odmdata:-${sw_var_odm:-"0x9c000"}}

    # XXX: remove odm override
    # Set ODM bits
    [[ -n $_battery ]] && _battery_odm $_battery
    [[ -n $_watchdog ]] && _watchdog_odm $_watchdog
    [[ -n $_modem ]] && _modem_odm $_modem

    if [ "$_fused" == "1" ]; then
        odmdata=$(printf "0x%x" $(( odmdata | (1 << 13) )) )
    fi

    local skipsanitize

    # Set skipsanitize option
    if [ "$sw_var_skip_sanitize" != "true" ]; then
        skipsanitize=""
    else
        skipsanitize="--skipsanitize"
    fi

    _tegraflash_update_partitions

    case $(getprop version) in
        2)
            _set_cmdline_tegraflash_v2
            ;;
        *)
            _set_cmdline_tegraflash_v1
            ;;
    esac

    cmdline=($(nvbin tegraflash.py) ${cmdline[@]})

    if [ "$skip_uid" == "1" ]; then
        cmdline=(${cmdline[@]} --skipuid)
        skip_uid=0
    fi
}
_set_cmdline_tegraflash_v1() {
    local bctfile=${sw_var_bct:-"bct_cboot.cfg"}
    if [ "$_fused" == "1" ]; then
        [[ $bctfile == *.cfg ]] && bctfile=${bctfile%.cfg}.bct || {
            pr_err "bctfile '$bctfile' doesn't end with .cfg" "_set_cmdline_tegraflash: "
            exit 1
        }
    fi

    cmdline=(
        --bct $bctfile
        --bl  $(getprop bl)
        --cfg $sw_var_cfg
        --odmdata $odmdata
        --bldtb $sw_var_dtb
        --chip $(getprop chip)
        --applet $(getprop applet)
        --nct $nctbin
        $skipsanitize
        $cmd
        $fbfile
        $instance
        $(getprop arg_secure)
        )

}
_set_cmdline_tegraflash_v2() {
    # BCT Configs
    local bct_configs=""
    [ -n "$sw_var_bct_configs_sdram" ]  && bct_configs+="--sdram_config $sw_var_bct_configs_sdram "
    [ -n "$sw_var_bct_configs_misc" ]   && bct_configs+="--misc_config $sw_var_bct_configs_misc "
    [ -n "$sw_var_bct_configs_pinmux" ] && bct_configs+="--pinmux_config $sw_var_bct_configs_pinmux "
    [ -n "$sw_var_bct_configs_scr" ]    && bct_configs+="--scr_config $sw_var_bct_configs_scr "
    [ -n "$sw_var_bct_configs_pmc" ]    && bct_configs+="--pmc_config $sw_var_bct_configs_pmc "
    [ -n "$sw_var_bct_configs_pmic" ]   && bct_configs+="--pmic_config $sw_var_bct_configs_pmic "
    [ -n "$sw_var_bct_configs_br_cmd" ] && bct_configs+="--br_cmd_config $sw_var_bct_configs_br_cmd "
    [ -n "$sw_var_bct_configs_prod" ]   && bct_configs+="--prod_config $sw_var_bct_configs_prod "
    [ -n "$sw_var_bct_configs_dev_params" ] && bct_configs+="--dev_params $sw_var_bct_configs_dev_params "

    # MTS Bins
    local mts_params="mts_preboot $sw_var_preboot; mts_bootpack $sw_var_bootpack; mb2_bootloader $(getprop bl_mb2)"
    mts_params="--bins \"$mts_params\""

    cmdline=(
        $bct_configs
        --bl  $(getprop bl)
        $mts_params
        --cfg $sw_var_cfg
        --odmdata $odmdata
        --chip $(getprop chip)
        --applet $(getprop applet)
        $cmd
        $fbfile
        $instance
        $(getprop arg_secure)
        )

}

_set_cmdline_xlate_flash_post() {
    local x tmp
    for x in "${flash_post[@]}"; do
        # copy fiels with abs path to $OUT for nvflash/cygwin
        [ "$flash_driver" == "tegraflash" ] && {
            tmp+="write $x;"
        } || {
            # flash_driver == "nvflash"
            [ "$OSTYPE" == "cygwin" ] && {
                # Make sure the target file is copied to $OUT
                local part_file=($x)
                local part=${part_file[0]}
                local file=${part_file[1]}
                local base=$(basename $file)
                [ "$file" != "$base" ] && {
                    pr_warn "[Cygwin NVFLASH WAR] Copying $file to $PRODUCT_OUT/$part.$cid" "_set_cmdline_xlate_flash_post: "
                    cp -fL $file $PRODUCT_OUT/$part.$cid || {
                        pr_err "Failed to copy $file to $PRODUCT_OUT/$part.$cid" "_set_cmdline_xlate_flash_post: "
                        exit 1
                    }
                    x="${part_file[0]} $part.$cid"
                }
            }
            tmp+="--download $x "
        }
    done
    flash_post="$tmp"
}

_set_cmdline() {
    if [ "$flash_driver" == "tegraflash" ]; then
        _set_cmdline_tegraflash
    elif [ "$flash_driver" == "bootburn" ]; then
        _set_cmdline_automotive
    else
        _set_cmdline_nvflash
    fi
}

parse_commands() {
    # Handle --instance for now. Do not handle other commands yet.
    commands=()
    local cmds=($@)
    local c breaker i=0
    for c;
    do
        ((i++))
        case $c in
        --) breaker=1
            ;;
        --instance)
            breaker=1
            pr_warn "--instance <instance> will be deprecated. Please use -i <instance>." "flash.sh: " >&2
            local _i="${cmds[i]}"
            if [ -z "$_i" ];then
                pr_err "--instance requires an argument" "flash.sh: " >&2
                usage
                exit 1
            else
                _instance=$_i
            fi
            ;;
        *)
            [ -z "$breaker" ] && commands+=($c)
            ;;
        esac
    done
}

###############################################################################
# Main code
###############################################################################

# convert args into an array
args_a=( "$@" )

ROOT_PATH=$PWD

HOST_BIN="${HOST_BIN:-$ROOT_PATH}"

if [ -z "$PRODUCT_OUT" ]; then
    PRODUCT_OUT=$ROOT_PATH
fi

# Convert HOST_BIN, PRODUCT_OUT and TNSPEC_WORKSPACE to absolute paths
_optional_dirs="TNSPEC_WORKSPACE"

for p in "HOST_BIN" "PRODUCT_OUT" "TNSPEC_WORKSPACE"
do
    _p="$(eval echo \"\$$p\")"
    ! _in_array $p $_optional_dirs && [ ! -d "$_p" ] && {
        pr_err "'$p=$_p' doesn't appear to be a directory" "flash.sh: "
        exit 1
    }
    [ -z "$_p" ] && continue
    case $_p in
        /*) eval $p=\"$_p\" ;;
        *)  eval $p=\"$PWD/$_p\" ;;
    esac
done

# Optional arguments
while getopts "no:s:m:b:w:i:fvzuhdeOFXN" OPTION
do
    case $OPTION in
    h) usage
        exit 0
        ;;
    z) _diags=1; _erase_all_partitions=1;
        ;;
    d)  _dryrun=1;
        ;;
    f)  _fused=1;
        ;;
    m) _modem=${OPTARG};
        ;;
    n) _nosudo=1;
        ;;
    i) _instance=${OPTARG};
        ;;
    o) _odmdata=${OPTARG};
        ;;
    s) _skuid=${OPTARG};
        _peek=${args_a[(( OPTIND - 1 ))]}
        if [ "$_peek" == "forcebypass" ]; then
            _skuid="$_skuid $_peek"
            shift
        fi
        ;;
    u) _unattended=1
        ;;
    v) _verbose=1
        ;;
    b) _battery=${OPTARG};
        ;;
    w) _watchdog=${OPTARG};
        ;;
    e) _erase_all_partitions=1;
        ;;
    O) _offline=1;
        ;;
    F) _force=1;
        ;;
    X) _exp=1;
        pr_info   ""
        pr_info   ""
        pr_info_b "**********************************************************"
        pr_info   ""
        pr_info   " -X is no longer needed to invoke the new flash interface."
        pr_info   ""
        pr_info_b "**********************************************************"
        pr_info   ""
        pr_info   ""
        ;;
    N) _no_track=1;
        ;;
    esac
done

tnspec_bin=$PRODUCT_OUT/tnspec.py

if [ ! -x "$tnspec_bin" ]; then
    pr_err "Error: $tnspec_bin doesn't exist or is not executable." "TNSPEC: " >&2
    exit 1
fi

if ! check_tools_system; then
    pr_err "Error: missing required tools." "flash.sh: " >&2
    exit 1
fi

# Detect OS
case $OSTYPE in
    cygwin)
        _nosudo=1
        umask 0000
        ;;
    linux*)
        umask 0002
        ;;
    *)
        pr_err "unsupported OS type $OSTYPE detected" "flash.sh: "
        exit 1
        ;;
esac

shift $(($OPTIND - 1))
parse_commands $@

# Set globals
! _shell_is_interactive && _unattended=1
[[ -n "$_instance" ]] && {
    instance="--instance $_instance"
}

# If BOARD is set, use it as predefined board name
[[ -n $BOARD ]] && board="$BOARD"

# Debug
[ "$_verbose" == "1" ] &&
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/stderr} ||
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/null}

[ ! -w "$TNSPEC_OUTPUT" ] && {
    pr_warn "$TNSPEC_OUTPUT doesn't have write access." "TNSPEC_OUTPUT: "
    exit 1
}

(cd $PRODUCT_OUT && flash_main)
