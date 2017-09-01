###############################################################################
#
# Copyright (c) 2010-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################

function _gethosttype()
{
    H=`uname`
    if [ "$H" == Linux ]; then
        HOSTTYPE="linux-x86"
    fi

    if [ "$H" == Darwin ]; then
        HOSTTYPE="darwin-x86"
        export HOST_EXTRACFLAGS="-I$(gettop)/vendor/nvidia/tegra/core-private/include"
    fi
}

function _getnumcpus ()
{
    # if we happen to not figure it out, default to 2 CPUs
    NUMCPUS=2

    _gethosttype

    if [ "$HOSTTYPE" == "linux-x86" ]; then
        NUMCPUS=`cat /proc/cpuinfo | grep processor | wc -l`
    fi

    if [ "$HOSTTYPE" == "darwin-x86" ]; then
        NUMCPUS=`sysctl -n hw.activecpu`
    fi
}

function is_build_foster_e()
{
    target=$(get_build_var TARGET_PRODUCT)
    FOSTER="foster_e"
    DARCY="darcy"
    DARCY_DIAG="darcy_diag"
    ret=0
    if [[ $target == *"$FOSTER"* ]]; then
      ret=1
    elif [[ $target == *"$DARCY"* ]] && [[ $target != *"$DARCY_DIAG"* ]]; then
      ret=1
    fi
    echo $ret
}

function get_flash_tool()
{
    flash="flash.sh"
    if [ $(is_build_foster_e) -eq 1 ]; then
        flash="flash_foster.sh"
    fi
    echo $flash
}

function get_tnspec_tool()
{
    flash="tnspec.py"
    if [ $(is_build_foster_e) -eq 1 ]; then
        flash="tnspec_foster.py"
    fi
    echo $flash
}

function _karch()
{
    # Some boards (eg. exuma) have diff ARCHes between
    # userspace and kernel, denoted by TARGET_ARCH and
    # TARGET_ARCH_KERNEL, whichever non-null is picked.
    local arch=$(get_build_var TARGET_ARCH_KERNEL)
    test -z $arch && arch=$(get_build_var TARGET_ARCH)
    echo $arch
}

function _ktoolchain()
{
    local build_id=$(get_build_var BUILD_ID)
    if [[ "$(_karch)" == arm64 ]]; then
         echo "CROSS_COMPILE=${ANDROID_TOOLCHAIN}/aarch64-linux-android-"
    else
         local PREBUILT_TAG=$(get_build_var HOST_PREBUILT_TAG)
         echo "CROSS_COMPILE=${TOP}/prebuilts/gcc/${PREBUILT_TAG}/arm/arm-eabi-4.8/bin/arm-eabi-"
    fi
}

function _default_kpath()
{
    T=$(gettop)
    local kpath=$(get_build_var KERNEL_PATH)
    kpath=${kpath:-$T/kernel}
    echo "$kpath"
}
function ksetup()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-$(_default_kpath)}
    if [ $# -lt 1 ] ; then
        echo "Usage: ksetup <defconfig> <path>"
        return 1
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi
    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$(_karch)"
    local SECURE_OS_BUILD=$(get_build_var SECURE_OS_BUILD)
    local DEFCONFIG_PATH="DEFCONFIG_PATH=$SRC/arch/$(_karch)/configs"
    local T18x_DEFCONFIG_REGEX="^tegra18_[a-zA-Z0-9_]*defconfig$"

    if [[ $1 =~ $T18x_DEFCONFIG_REGEX ]]; then
        DEFCONFIG_PATH="DEFCONFIG_PATH=$T/kernel-t18x/arch/$(_karch)/configs"
    fi

    echo "mkdir -p $KOUT"
    echo "make -C $SRC $KARCH $CROSS O=$KOUT $DEFCONFIG_PATH $1"
    (cd $T && mkdir -p $KOUT ; make -C $SRC $KARCH $CROSS O=$KOUT $DEFCONFIG_PATH $1)

    if [ "$SECURE_OS_BUILD" == "tlk" ]; then
        $SRC/scripts/config --file $KOUT/.config --enable TRUSTED_LITTLE_KERNEL \
             --enable OTE_ENABLE_LOGGER --enable TEGRA_USE_SECURE_KERNEL
    fi
    if [[ "$TARGET_BUILD_TYPE" == "release" && "$TARGET_BUILD_VARIANT" == "user" ]]; then
        $SRC/scripts/config --file $KOUT/.config --enable CONTROL_CONSOLE_WRITE\
             --disable DEVMEM
    fi

    if [ "$NVIDIA_KERNEL_COVERAGE_ENABLED" == "1" ]; then
        echo "Explicitly enabling coverage support in kernel config on user request"
        $SRC/scripts/config --file $KOUT/.config \
            --enable DEBUG_FS \
            --enable GCOV_KERNEL \
            --enable GCOV_TOOLCHAIN_IS_ANDROID \
            --disable GCOV_PROFILE_ALL
    fi
    if [ "$NV_AUTOMOTIVE_BUILD" == "true" ] && [ "$NV_ANDROID_FRAMEWORK_ENHANCEMENTS" != "TRUE" ]; then
        if [ "$REFERENCE_DEVICE" == "p1859" ]; then
        $SRC/scripts/config --file $KOUT/.config \
            --enable PCI_TEGRA \
            --enable SATA_AHCI_TEGRA \
            --enable SND_SOC_TEGRA_VCM30T124_ALT \
            --enable USB_XHCI_HCD \
            --enable USB_EHCI_HCD \
            --enable RTC_DRV_MAX77663 \
            --enable DYNAMIC_DEBUG
        fi
    fi
}

function kconfig()
{
   T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-$(_default_kpath)}
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$(_karch)"

    echo "make -C $SRC $KARCH $CROSS $KOUT menuconfig"
    (cd $T && make -C $SRC $KARCH $CROSS $KOUT menuconfig)
}

function ksavedefconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-$(_default_kpath)}
    if [ $# -lt 1 ] ; then
        echo "Usage: ksavedefconfig <defconfig> [kernelpath]"
        return 1
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype

    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local KOUT="$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)
    local KARCH="ARCH=$(_karch)"
    local DEFCONFIG_PATH="$SRC/arch/$(_karch)/configs"
    local T18x_DEFCONFIG_REGEX="^tegra18_[a-zA-Z0-9_]*defconfig$"

    if [[ $1 =~ $T18x_DEFCONFIG_REGEX ]]; then
        DEFCONFIG_PATH="$T/kernel-t18x/arch/$(_karch)/configs"
    fi

    # make a backup of the current configuration
    cp $KOUT/.config $KOUT/.config.backup

    # CONFIG_TRUSTED_LITTLE_KERNEL is turned on in kernel.mk or
    # ksetup rather than defconfig don't store coverage setup to defconfig
    $SRC/scripts/config --file $KOUT/.config \
        --disable TRUSTED_LITTLE_KERNEL \
        --disable TEGRA_USE_SECURE_KERNEL \
        --disable GCOV_KERNEL \
        --disable OTE_ENABLE_LOGGER \
        --disable TEGRA_USE_SECURE_KERNEL

    echo "make -C $SRC $KARCH $CROSS O=$KOUT savedefconfig"
    (cd $T && make -C $SRC $KARCH $CROSS O=$KOUT savedefconfig &&
        cp $KOUT/defconfig $DEFCONFIG_PATH/$1)

    # restore configuration from backup
    rm $KOUT/.config
    mv $KOUT/.config.backup $KOUT/.config
}

function krebuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KERNEL_PATH:-$(_default_kpath)}
    if [ -d "$1" ] ; then
        SRC="$1"
        shift 1
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _gethosttype
    _getnumcpus

    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local TOOLS=$(get_build_var TARGET_TOOLS_PREFIX)
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local HOSTOUT=$(get_build_var HOST_OUT)
    local MKBOOTIMG=$T/$HOSTOUT/bin/mkbootimg
    local LZ4C=$T/$HOSTOUT/bin/lz4c
    local KERNEL_COMPRESS=$(get_build_var BOARD_SUPPORT_KERNEL_COMPRESS)
    if [[ $(_karch) = "arm64" ]]; then
        local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/$(_karch)/boot/Image
        if [[ $KERNEL_COMPRESS = "gzip" ]]; then
            ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/$(_karch)/boot/zImage
        fi
        if [[ $KERNEL_COMPRESS = "lz4" ]]; then
            local COMPRESSED_KERNEL=$T/$INTERMEDIATES/KERNEL/arch/$(_karch)/boot/zImage.lz4
            $LZ4C -c1 -l -f $ZIMAGE $COMPRESSED_KERNEL
            ZIMAGE=$COMPRESSED_KERNEL
        fi
        local KCFLAGS="KCFLAGS=-mno-android"
    else
        local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/$(_karch)/boot/zImage
    fi
    local RAMDISK=$T/$OUTDIR/ramdisk.img

    local KOUT="O=$T/$INTERMEDIATES/KERNEL"
    local CROSS=$(_ktoolchain)

    local PLATFORM_IS_AFTER_LOLLIPOP=$(get_build_var PLATFORM_IS_AFTER_LOLLIPOP)

    if [ ${PLATFORM_IS_AFTER_LOLLIPOP} != "1" ]; then
        local CROSS32CC="CROSS32CC=${ARM_EABI_TOOLCHAIN}/arm-eabi-gcc"
    else
        local PREBUILT_TAG=$(get_build_var HOST_PREBUILT_TAG)
        CROSS32CC="CROSS32CC=${TOP}/prebuilts/gcc/${PREBUILT_TAG}/arm/arm-eabi-4.8/bin/arm-eabi-gcc"
    fi

    local KARCH="ARCH=$(_karch)"

    if [ ! -f "$RAMDISK" ]; then
        echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
        return 1
    fi

    echo "make -j$NUMCPUS -l$NUMCPUS -C $SRC $* $KARCH $CROSS $CROSS32CC $KCFLAGS $KOUT LOCALVERSION=-tegra"
    (cd $T && make -j$NUMCPUS -l$NUMCPUS -C $SRC $* $KARCH $CROSS $CROSS32CC $KCFLAGS $KOUT LOCALVERSION=-tegra)
    local ERR=$?

    if [ $ERR -ne 0 ] ; then
	return $ERR
    fi

    if [ -d "$T/$OUTDIR/modules" ] ; then
        rm -r $T/$OUTDIR/modules
    fi

    (mkdir -p $T/$OUTDIR/modules \
        && cd $T && make modules_install -C $SRC $KARCH $CROSS $CROSS32CC $KOUT INSTALL_MOD_PATH=$T/$OUTDIR/modules \
        && mkdir -p $T/$OUTDIR/system/lib/modules && cp -f `find $T/$OUTDIR/modules -name *.ko` $T/$OUTDIR/system/lib/modules \
        && $MKBOOTIMG --kernel $ZIMAGE --ramdisk $RAMDISK --output $T/$OUTDIR/boot.img )

    echo "$OUT/boot.img created successfully."

    if [[ $KARCH =~ "arm64" && -f ${OUT}/full_filesystem.img ]]; then
        local bwdir=$TOP/kernel-build/boot-wrapper-aarch64
        local TARGET_KERNEL_DT_NAME=$(get_build_var SIM_KERNEL_DT_NAME)
        local KERNEL_DT_PATH=$SRC/arch/arm64/boot/dts/${TARGET_KERNEL_DT_NAME}.dts
        make -C $bwdir FDT_SRC=${KERNEL_DT_PATH}
    fi

    #Copy DTB's from the intermediate build directory to $OUT
    cp $OUT/obj/KERNEL/arch/$(_karch)/boot/dts/*.dtb $OUT
}

function buildsparse()
{
    #build kernel and kernel modules with Sparse
    SPARSE=$(which sparse)
    if [ ! "$SPARSE" ]; then
        echo "Couldn't locate the sparse." >&2
        echo "For more details see :" >&2
        echo "https://wiki.nvidia.com/wmpwiki/index.php/System_SW/Static_Analysis/sparse" >&2
        return 1
    fi
    krebuild C=2 CHECK=$SPARSE $1
}

function build_single_dtb()
{
    local DTS_NAME="$1"
    local DTB_NAME=${DTS_NAME/.dts/.dtb}

    echo $DTB_NAME
    ksetup $DTB_NAME
    cp $OUT/obj/KERNEL/arch/$(_karch)/boot/dts/$DTB_NAME $OUT
    echo "$OUT/$DTB_NAME created successfully."
}

function builddtb()
{
    local TARGET_KERNEL_DT_NAME=$(get_build_var TARGET_KERNEL_DT_NAME)
    local KERNEL_DT_NAME=${TARGET_KERNEL_DT_NAME%%-*}
    local SRC=${KERNEL_PATH:-$(_default_kpath)}

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    for _DTS_PATH in $SRC/arch/$(_karch)/boot/dts/$KERNEL_DT_NAME-*.dts
    do
        build_single_dtb ${_DTS_PATH##*/}
    done
}

function buildsysimg()
{
    local OUT=$(get_build_var OUT)
    local TARGET_OUT=$OUT/system
    local systemimage_intermediates=$OUT/obj/PACKAGING/systemimage_intermediates
    $TOP/build/tools/releasetools/build_image.py $TARGET_OUT $systemimage_intermediates/system_image_info.txt $systemimage_intermediates/system.img
    cp $systemimage_intermediates/system.img $OUT/
    echo "$OUT/system.img created successfully."
}

function buildall()
{
    #build kernel and kernel modules
    krebuild

    #build board's device tree blob (dtb)
    builddtb

    #create system.img
    buildsysimg
}

# allow us to override Google defined functions to apply local fixes
# see: http://mivok.net/2009/09/20/bashfunctionoverrist.html
_save_function()
{
    local oldname=$1
    local newname=$2
    local code=$(declare -f ${oldname})
    eval "${newname}${code#${oldname}}"
}

#
# Unset variables known to break or harm the Android Build System
#
#  - CDPATH: breaks build
#    https://groups.google.com/forum/?fromgroups=#!msg/android-building/kW-WLoag0EI/RaGhoIZTEM4J
#
_save_function m  _google_m
function m()
{
    CDPATH= _google_m $*
}

_save_function mm _google_mm
function mm()
{
    CDPATH= _google_mm $*
}

function mp()
{
    _getnumcpus
    m -j$NUMCPUS -l$NUMCPUS $*
}

function mmp()
{
    _getnumcpus
    mm -j$NUMCPUS -l$NUMCPUS $*
}

function fboot()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local ZIMAGE=$T/$INTERMEDIATES/KERNEL/arch/$(_karch)/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot
    local vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$ZIMAGE" ]; then
            echo "Couldn't find $ZIMAGE. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        if [ ! -f "$RAMDISK" ]; then
            echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        CMD="-i $vendor_id boot $ZIMAGE $RAMDISK"
    fi

    echo "sudo $FASTBOOT $CMD"
    (eval sudo $FASTBOOT $CMD)
}

function fflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local BOOTIMAGE=$T/$OUTDIR/boot.img
    local SYSTEMIMAGE=$T/$OUTDIR/system.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot

    local DTBIMAGE=$T/$OUTDIR/$(get_build_var TARGET_KERNEL_DT_NAME).dtb
    local vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$BOOTIMAGE" ]; then
            echo "Couldn't find $BOOTIMAGE. Check your build for any error." >&2
            return 1
        fi
        if [ ! -f "$SYSTEMIMAGE" ]; then
            echo "Couldn't find $SYSTEMIMAGE. Check your build for any error." >&2
            return 1
        fi
        CMD="-i $vendor_id flash system $SYSTEMIMAGE flash boot $BOOTIMAGE"
        if [ "$DTBIMAGE" != "" ] && [ -f "$DTBIMAGE" ]; then
            CMD=$CMD" flash dtb $DTBIMAGE"
        fi
        CMD=$CMD" reboot"
    fi

    echo "sudo $FASTBOOT $CMD"
    (sudo $FASTBOOT $CMD)
}

function _flash()
{
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
    local HOST_OUT=$(get_build_var HOST_OUT)

    # _nvflash_sh uses the 'bsp' argument to create BSP flashing script
    if [[ "$1" == "bsp" ]]; then
        T="\$(pwd)"
        local FLASH_SH="$T/$PRODUCT_OUT/flash.sh \$@"
        shift
    else
        T=$(gettop)
        FLASH_SH=$(get_flash_tool)
        local FLASH_SH=$T/vendor/nvidia/build/$FLASH_SH
    fi

    local cmdline=(
        PRODUCT_OUT=$T/$PRODUCT_OUT
        HOST_BIN=\${HOST_BIN:-$T/$HOST_OUT/bin}
        $FLASH_SH
        $@
    )

    echo ${cmdline[@]}
}

function flash()
{
    eval $(_flash $@)
}

function vcm_flash()
{
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
    local TARGET_DEVICE=$(get_build_var TARGET_DEVICE)
    TARGET_DEVICE=$TARGET_DEVICE $PRODUCT_OUT/vcm_flash.sh $@
}

# Print out a shellscript for flashing BSP or buildbrain package
# and copy the core script to PRODUCT_OUT
function _nvflash_sh()
{
    T=$(gettop)
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
    local HOST_OUT=$(get_build_var HOST_OUT)

    FLASH_SH=$(get_flash_tool)
    TNSPEC_PY=$(get_tnspec_tool)
    # Vibrante Android requires own flash script.
    local NV_REQUIRES_EMBEDDED_FOUNDATION=$(get_build_var NV_REQUIRES_EMBEDDED_FOUNDATION)
    if [[ "${NV_REQUIRES_EMBEDDED_FOUNDATION}" != true ]]; then
        cp -f $T/vendor/nvidia/build/$FLASH_SH $PRODUCT_OUT/flash.sh

        # WAR - tnspec.py can be missing in some packages.
        cp -f $T/vendor/nvidia/tegra/core/tools/tnspec/$TNSPEC_PY $PRODUCT_OUT/tnspec.py
    fi


    # Unified flashing command
    local cmd='#!/bin/bash

# enable globbing in case it has already been turned off
set +f

pkg_filter=android_*_os_image-*.tgz
pkg=$(echo $pkg_filter)
pkg_dir="_${pkg/%.tgz}"
host_bin="$HOST_OUT/bin"

if [[ "$pkg" != "$pkg_filter" && -f $pkg && ! -d "$pkg_dir" ]]; then
    echo "Extracting $pkg...."
    mkdir $pkg_dir
    (cd $pkg_dir && tar xfz ../$pkg)
    find $pkg_dir -maxdepth 2 -type f -exec cp -u {} $PRODUCT_OUT \;

    # copy host bins
    find $pkg_dir -path \*$host_bin\* -type f -exec cp -u {} $host_bin \;

    # check if system_gen.sh was used
    x=$(basename $pkg_dir/android_*_os_image*)
    [ -d "$x" ] && {
        echo "************************************************************"
        echo
        echo "WARNING:"
        echo "    Looks like \"system_img.gen\" was used."
        echo "    \"./flash.sh\" is the only script needed for flashing."
        echo
        echo "************************************************************"
    }
fi
'
    cmd=${cmd//\$PRODUCT_OUT/$PRODUCT_OUT}
    cmd=${cmd//\$HOST_OUT/$HOST_OUT}

    echo "$cmd"
    if [[ "${NV_REQUIRES_EMBEDDED_FOUNDATION}" == true ]]; then
        sed -e "s/\$TARGET_BUILD_TYPE/$TARGET_BUILD_TYPE/g" \
            -e "s/\$TARGET_DEVICE/$(get_build_var TARGET_DEVICE)/g" \
            -e "s/^#.*//g" \
            $PRODUCT_OUT/vcm_flash.sh
    else
        echo "($(_flash bsp))"
    fi
}


function adbserver()
{
    f=$(pgrep adb)
    if [ $? -ne 0 ]; then
        ADB=$(which adb)
        echo "Starting adb server.."
	sudo ${ADB} start-server
    fi
}

function nvlog()
{
    T=$(gettop)
    if [ ! "$T" ]; then
	echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
	return 1
    fi
    adbserver
    adb logcat | $T/vendor/nvidia/build/asymfilt.py
}

function stayon()
{
    adbserver
    adb shell "svc power stayon true && echo main >/sys/power/wake_lock"
}

function _tnspec_which()
{
    T=$(gettop)
    local PRODUCT_OUT=$T/$(get_build_var PRODUCT_OUT)

    local tnspec_spec=$PRODUCT_OUT/tnspec.json
    local tnspec_spec_public=$PRODUCT_OUT/tnspec-public.json

    if [ -f $tnspec_spec ]; then
        echo $tnspec_spec
    elif [ -f $tnspec_spec_public ]; then
        echo $tnspec_spec_public
    elif [ ! -f $tnspec_spec_public ]; then
        echo "Error: tnspec.json doesn't exist. $tnspec_spec $tnspec_spec_public" >&2
    fi
}

function _tnspec()
{
    T=$(gettop)
    local PRODUCT_OUT=$T/$(get_build_var PRODUCT_OUT)

    local tnspec_bin=$PRODUCT_OUT/tnspec.py

    # return nothing if tnspec tool or spec file is missing
    if [ ! -x $tnspec_bin ]; then
        echo "Error: tnspec.py doesn't exist or is not executable. $tnspec_bin" >&2
        return
    fi

    $tnspec_bin $*
}

function tnspec()
{
    _tnspec $* -s $(_tnspec_which)
}

function tntest()
{
    T=$(gettop)
    $T/vendor/nvidia/tegra/core/tools/tntest/tntest.sh $@
}

function kupdate()
{
    OVERRIDE_SW="kernel.update_nct=false" flash -O auto kernel
}

# XXX: Remove this function.
function flash_sn()
{
    echo "Deprecated. Use 'flash tnspec' command instead."
}

# Add Nvidia .PHONY build goals to Kati parse time make goals list
# NOTE: if you add a goal to the build then you *MUST* update this list too!
_nvidia_parse_time_goals=(
    dev
    kernel-tests
    nv-blob
    nvidia-google-tests
    nvidia-tests
    nvidia-tests-automation
    otapackage
    sim-image
)
export PARSE_TIME_MAKE_GOALS="${_nvidia_parse_time_goals[@]}"
unset _nvidia_parse_time_goals

# Enable "ninja + PR#1139: ninja as GNU make jobserver client" mode
export USE_NINJA_JOBSERVER_CLIENT=true

# Remove TEGRA_ROOT, no longer required and should never be used.

if [ -n "$TEGRA_ROOT" ]; then
    echo "WARNING: TEGRA_ROOT env variable is set to: $TEGRA_ROOT"
    echo "This variable has been superseded by TEGRA_TOP."
    echo "Removing TEGRA_ROOT from environment"
    unset TEGRA_ROOT
fi

if [ -f $HOME/lib/android/envsetup.sh ]; then
    echo including $HOME/lib/android/envsetup.sh
    .  $HOME/lib/android/envsetup.sh
fi

if [ -d $(gettop)/vendor/nvidia/proprietary_src ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/proprietary_src
elif [ -d $(gettop)/vendor/nvidia/tegra ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/tegra
else
    echo "WARNING: Unable to set TEGRA_TOP environment variable."
    echo "Valid TEGRA_TOP directories are:"
    echo "$(gettop)/vendor/nvidia/proprietary_src"
    echo "$(gettop)/vendor/nvidia/tegra"
    echo "At least one of them should exist."
    echo "Please make sure your Android source tree is setup correctly."
    # This script will be sourced, so use return instead of exit
    return 1
fi

if [ -f $TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip ]; then
    export PDK_FUSION_PLATFORM_ZIP=$TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip
fi

if [ `uname` == "Darwin" ]; then
    if [[ -n $FINK_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${FINK_ROOT}/lib/coreutils/bin
    elif [[ -n $MACPORTS_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${MACPORTS_ROOT}/local/libexec/gnubin
    elif [[ -n $GNU_COREUTILS ]]; then
        :
    else
        echo "Cannot find GNU coreutils. Please set either GNU_COREUTILS, FINK_ROOT or MACPORTS_ROOT."
    fi
fi

# Disabled in early development phase.
#if [ -f $TEGRA_TOP/tmake/scripts/envsetup.sh ]; then
#    _nvsrc=$(echo ${TEGRA_TOP}|colrm 1 `echo $TOP|wc -c`)
#    echo "including ${_nvsrc}/tmake/scripts/envsetup.sh"
#    . $TEGRA_TOP/tmake/scripts/envsetup.sh
#fi

# Temporary HACK to remove pieces of the PDK
if [ -n "$PDK_FUSION_PLATFORM_ZIP" ]; then
    zip -q -d $PDK_FUSION_PLATFORM_ZIP "system/vendor/*" >/dev/null 2>/dev/null || true
fi
