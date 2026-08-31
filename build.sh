#!/bin/bash
KVER="-v1.1"
RVER="-v1.1"

abort()
{
    cd -
    echo "-----------------------------------------------"
    echo "Kernel compilation failed! Exiting..."
    echo "-----------------------------------------------"
    exit -1
}

unset_flags()
{
    cat << EOF
Usage: $(basename "$0") [options]
Options
    -m, --model [value]            Specify the region code of the phone
    -d, --droidspaces [y/N]        Include Droidspaces support
    -k, --ksu [y/N]                Include KernelSU
    -s, --susfs [y/N]              Include SuSFS
    -r, --recovery [y/N]           Compile kernel for an Android Recovery
    -o, --odin [y/N]               Compile images flashable via Odin
    -c, --clean                    Clean build
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model|-m)
            MODEL="$2"
            shift 2
            ;;
        --droidspaces|-d)
            DS_OPTION="$2"
            shift 2
            ;;
        --ksu|-k)
            KSU_OPTION="$2"
            shift 2
            ;;
        --susfs|-s)
            SUSFS_OPTION="$2"
            shift 2
            ;;
        --recovery|-r)
            RECOVERY_OPTION="$2"
            shift 2
            ;;
        --odin|-o)
            ODIN_OPTION="$2"
            shift 2
            ;;
        --clean|-c)
            CLEAN_OPTION="y"
            shift
            ;;
        *)\
            unset_flags
            exit 1
            ;;
    esac
done

enable_susfs() {
    COMMON_DIR="${ANDROID_BUILD_TOP}/kernel_platform/common"
    KSUN_DIR="${COMMON_DIR}/KernelSU-Next"
    PATCH_FILE="${ANDROID_BUILD_TOP}/patches/0001-Enable-SuSFS-2.2.0-KSU-Next.patch"
    SUS_MARKER="config KSU_SUSFS"

    if [ ! -f "${PATCH_FILE}" ]; then
        echo "Patch not found:"
        echo "  ${PATCH_FILE}"
        exit 1
    fi

    echo "Checking patch..."

    if grep -q "${SUS_MARKER}" "${KSUN_DIR}/kernel/Kconfig" 2>/dev/null; then

        echo "SuSFS already enabled, Skipping patch."
        return
    fi

    echo "Applying SuSFS patch..."

    patch -d "${KSUN_DIR}" -p1 < "${PATCH_FILE}" || {
        echo "Failed to apply patch!"
        exit 1
    }
}

update_submodules() {

    echo "Updating submodules..."
    git submodule update --init --recursive --remote || exit 1

}

echo "Preparing the build environment..."

pushd $(dirname "$0") > /dev/null

SCRIPT_DIR="$(dirname $(readlink -fq $0))"
VERSION_FILE="${SCRIPT_DIR}/.build_incremental"

if [[ -f "${VERSION_FILE}" ]]; then
    BUILD_VERSION=$(( $(cat "${VERSION_FILE}") + 1 ))
else
    BUILD_VERSION=1
fi

echo "${BUILD_VERSION}" > "${VERSION_FILE}"

# Define specific variables
case $MODEL in
eur)
    BUILD_TARGET=b4q_eur_openx
;;
kor)
    BUILD_TARGET=b4q_kor_singlex
;;
jpr)
    BUILD_TARGET=b4q_jpn_rktw
;;
jpd)
    BUILD_TARGET=b4q_jpn_dcmw
;;
jpk)
    BUILD_TARGET=b4q_jpn_kdiw
;;
*)
    unset_flags
    exit
esac

export MODEL=$(echo $BUILD_TARGET | cut -d'_' -f1)
export PROJECT_NAME=${MODEL}
export REGION=$(echo $BUILD_TARGET | cut -d'_' -f2)
export CARRIER=$(echo $BUILD_TARGET | cut -d'_' -f3)
export TARGET_BUILD_VARIANT=user

CHIPSET_NAME=waipio

export ANDROID_BUILD_TOP=$(pwd)
export TARGET_PRODUCT=gki
export TARGET_BOARD_PLATFORM=gki

sudo timedatectl set-timezone "Asia/Manila" || export TZ="Asia/Manila"
export KBUILD_BUILD_USER="$(id -un)"
export KBUILD_BUILD_HOST="$(hostname)"
export KBUILD_BUILD_TIMESTAMP=$(date)
export KBUILD_BUILD_VERSION="${BUILD_VERSION}"


export LOCALVERSION="$VERSION_SUFFIX"

export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}
export DIST_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}/dist
export MERGE_CONFIG="${ANDROID_BUILD_TOP}/kernel_platform/common/scripts/kconfig/merge_config.sh"

export CUST_DEFCONFIG="custom_defconfigs/b4q_defconfig"

mkdir -p "${DIST_DIR}"
    
if [ ! -d "${ANDROID_PRODUCT_OUT}" ]; then
    mkdir -p "${ANDROID_PRODUCT_OUT}"
fi

export KBUILD_EXTRA_SYMBOLS="${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/mmrm-driver/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet/core/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/wlan/qcacld-3.0/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/camera-kernel/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/eva-kernel/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/video-driver/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/display-drivers/msm/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/aps/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/wlan/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/shs/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/perf_tether/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/perf/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/sch/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/datarmnet-ext/offload/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/dataipa/drivers/platform/msm/Module.symvers \
	${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/audio-kernel/Module.symvers"

export MODNAME=audio_dlkm

export KBUILD_EXT_MODULES="../vendor/qcom/opensource/wlan/qcacld-3.0 \
    ../vendor/qcom/opensource/dataipa/drivers/platform/msm \
    ../vendor/qcom/opensource/datarmnet/core \
    ../vendor/qcom/opensource/datarmnet-ext/aps \
    ../vendor/qcom/opensource/datarmnet-ext/offload \
    ../vendor/qcom/opensource/datarmnet-ext/shs \
    ../vendor/qcom/opensource/datarmnet-ext/sch \
    ../vendor/qcom/opensource/datarmnet-ext/perf \
    ../vendor/qcom/opensource/datarmnet-ext/perf_tether \
    ../vendor/qcom/opensource/datarmnet-ext/wlan \
    ../vendor/qcom/opensource/mmrm-driver \
    ../vendor/qcom/opensource/audio-kernel \
    ../vendor/qcom/opensource/camera-kernel \
    ../vendor/qcom/opensource/display-drivers/msm \
    ../vendor/qcom/opensource/eva-kernel \
    ../vendor/qcom/opensource/video-driver"

export MKBOOTIMG_EXTRA_ARGS="
    --header_version 4 \
    --os_version 12.0.0 \
    --os_patch_level 2026-07 \
    --pagesize 4096 \
"

# Define toolchain variables
CLANG_DIR=${ANDROID_BUILD_TOP}/kernel_platform/prebuilts/clang/host/linux-x86/clang-r614150
CLANG_VERSION="${CLANG_DIR##*-}"

for config in \
    "${ANDROID_BUILD_TOP}/kernel_platform/common/build.config.constants" \
    "${ANDROID_BUILD_TOP}/kernel_platform/msm-kernel/build.config.constants"
do
    if [ -f "$config" ]; then
        CURRENT=$(grep '^CLANG_VERSION=' "$config" | cut -d= -f2)

        if [ "$CURRENT" != "$CLANG_VERSION" ]; then
            echo "Updating $(basename "$config"): $CURRENT -> $CLANG_VERSION"
            sed -i "s/^CLANG_VERSION=.*/CLANG_VERSION=${CLANG_VERSION}/" "$config"
        else
            echo "$(basename "$config"): CLANG_VERSION=${CLANG_VERSION} (already up to date)"
        fi
    fi
done

# Update STRIP_TOOL in vendor boot/dlkm scripts
for script in \
    "${ANDROID_BUILD_TOP}/prebuilts/build_vendor_boot.sh" \
    "${ANDROID_BUILD_TOP}/prebuilts/build_vendor_dlkm.sh"
do
    if [ -f "$script" ]; then
        CURRENT=$(grep '^STRIP_TOOL=' "$script" | sed 's/.*clang-\([^/]*\).*/\1/')

        if [ "$CURRENT" != "$CLANG_VERSION" ]; then
            echo "Updating $(basename "$script"): clang-${CURRENT} -> clang-${CLANG_VERSION}"

            sed -i \
                "s|^STRIP_TOOL=.*|STRIP_TOOL=\"\${REPO_ROOT}/kernel_platform/prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}/bin/llvm-strip\"|" \
                "$script"
        else
            echo "$(basename "$script"): STRIP_TOOL already uses clang-${CLANG_VERSION}"
        fi
    fi
done

# Check if toolchain exists
if [ ! -f "$CLANG_DIR/bin/clang-23" ]; then
    echo "-----------------------------------------------"
    echo "Toolchain not found! Downloading..."
    echo "-----------------------------------------------"
    rm -rf $CLANG_DIR
    mkdir -p $CLANG_DIR
    pushd $CLANG_DIR > /dev/null
    curl -LJOk https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/mirror-goog-main-llvm-toolchain-source/clang-r614150.tar.gz
    tar xf mirror-goog-main-llvm-toolchain-source-clang-r614150.tar.gz
    rm mirror-goog-main-llvm-toolchain-source-clang-r614150.tar.gz
    echo "Cleaning up..."
    popd > /dev/null
fi

export RECOVERY_OPTION
export DS_OPTION
export KSU_OPTION
export SUSFS_OPTION

if [[ "$RECOVERY_OPTION" == "y" ]]; then
    export RECOVERY=recovery_defconfig
    export SUSFS_OPTION=n
    export KSU_OPTION=n
fi

if [[ "$ODIN_OPTION" == "y" ]]; then
    ODIN=y
fi

if [[ "$DS_OPTION" == "y" ]]; then
    export DS=droidspaces_defconfig
fi

if [[ "$KSU_OPTION" == "y" ]]; then
    export KSU=ksu_defconfig
fi

if [[ "$SUSFS_OPTION" == "y" ]]; then
    export SUSFS=susfs_defconfig
fi

if [ ! -d "${ANDROID_BUILD_TOP}/release" ]; then
    mkdir -p "${ANDROID_BUILD_TOP}/release"
    mkdir -p "${ANDROID_BUILD_TOP}/release/zip"
    mkdir -p "${ANDROID_BUILD_TOP}/release/tar"
fi

set_localversion() {
    CONFIG_FILE="${ANDROID_BUILD_TOP}/${CUST_DEFCONFIG}"

    OL=$(grep -E '^CONFIG_LOCALVERSION=' "$CONFIG_FILE")

    if [[ -z "$OL" ]]; then
        echo "ERROR: CONFIG_LOCALVERSION not found in ${CONFIG_FILE}"
        return 1
    fi

    BASE_LV=$(echo "$OL" | cut -d'"' -f2)

    trap 'sed -i "s|^CONFIG_LOCALVERSION=.*|${OL}|" "$CONFIG_FILE"' EXIT

    if [[ "$RECOVERY_OPTION" != "y" ]]; then
        VRSN="$KVER"
    else
        VRSN="$RVER"
    fi

    if [[ "$RECOVERY_OPTION" == "y" ]]; then
        LV_SUFFIX="-TWRP"
    elif [[ "$KSU_OPTION" == "y" && "$SUSFS_OPTION" == "y" ]]; then
        LV_SUFFIX="-KSUN-SUSFS"
    else
        LV_SUFFIX="-KSUN"
    fi

    UPDATED_LV="${BASE_LV}-${MODEL}${VRSN}${LV_SUFFIX}"

    sed -i \
        "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"${UPDATED_LV}\"|" \
        "$CONFIG_FILE"

    echo "LOCALVERSION: ${UPDATED_LV}"
}

get_common_build_options() {
    echo "
    SKIP_MRPROPER=1 \
    LTO=thin \
    HERMETIC_TOOLCHAIN=0 \
    KMI_SYMBOL_LIST_STRICT_MODE=0 \
    RECOMPILE_KERNEL=1 \
    ABI_DEFINITION= \
    BUILD_BOOT_IMG=1 \
    SKIP_VENDOR_BOOT=1 \
    MKBOOTIMG_PATH=${ANDROID_BUILD_TOP}/kernel_platform/tools/mkbootimg/mkbootimg.py \
    BOOT_IMAGE_HEADER_VERSION=4 \
    KERNEL_BINARY=Image \
    "
}

build_kernel() {
    # Build kernel image
    echo "-----------------------------------------------"
    echo "Defconfig: "$CUST_DEFCONFIG""

    if [ -z "$KSU" ]; then
        echo "KSU: N"
    else
        echo "KSU: $KSU"
    fi
    if [ -z "$SUSFS" ]; then
        echo "SUSFS: N"
    else
        echo "SUSFS: $SUSFS"
    fi
    if [ -z "$DS" ]; then
        echo "Droidspaces: N"
    else
        echo "Droidspaces: $DS"
    fi
    if [ -z "$RECOVERY" ]; then
        echo "Recovery: N"
    else
        echo "Recovery: Y"
    fi
    if [ -z "$ODIN" ]; then
        echo "ODIN: N"
    else
        echo "ODIN: Y"
    fi
    
    COMMON_OPTIONS=$(get_common_build_options)
    export GKI_KERNEL_BUILD_OPTIONS="${COMMON_OPTIONS}"
    COMMON_CONFIG="${CUST_DEFCONFIG}"

    if [ -f "${COMMON_CONFIG}" ]; then
        echo "Merging Common device config: ${COMMON_CONFIG}"
        export POST_DEFCONFIG_CMDS="check_defconfig && ${MERGE_CONFIG} -m \${OUT_DIR}/gki_kernel/common/.config ${ANDROID_BUILD_TOP}/${COMMON_CONFIG}"
        
        if [[ "$RECOVERY_OPTION" == "y" ]]; then
            echo "Merging Recovery config: ${RECOVERY}"
            export POST_DEFCONFIG_CMDS="${POST_DEFCONFIG_CMDS} && ${MERGE_CONFIG} -m \${OUT_DIR}/gki_kernel/common/.config ${ANDROID_BUILD_TOP}/custom_defconfigs/${RECOVERY}"
        fi

        if [[ "$DS_OPTION" == "y" ]]; then
            echo "Merging DroidSpaces config: ${DS}"
            export POST_DEFCONFIG_CMDS="${POST_DEFCONFIG_CMDS} && ${MERGE_CONFIG} -m \${OUT_DIR}/gki_kernel/common/.config ${ANDROID_BUILD_TOP}/custom_defconfigs/${DS}"
        fi

        if [[ "$KSU_OPTION" == "y" ]]; then
            echo "Merging KSU config: ${KSU}"
            export POST_DEFCONFIG_CMDS="${POST_DEFCONFIG_CMDS} && ${MERGE_CONFIG} -m \${OUT_DIR}/gki_kernel/common/.config ${ANDROID_BUILD_TOP}/custom_defconfigs/${KSU}"
        fi

        if [[ "$SUSFS_OPTION" == "y" ]]; then
            echo "Merging SuSFS config: ${SUSFS}"
            export POST_DEFCONFIG_CMDS="${POST_DEFCONFIG_CMDS} && ${MERGE_CONFIG} -m \${OUT_DIR}/gki_kernel/common/.config ${ANDROID_BUILD_TOP}/custom_defconfigs/${SUSFS}"
        fi
    else
        echo "Warning: Common config '${COMMON_CONFIG}' not found!"
    fi
        
    echo "Building kernel..."
    echo "-----------------------------------------------"
    if [[ "$ODIN_OPTION" == "y" ]]; then
        env ${GKI_KERNEL_BUILD_OPTIONS} GKI_RAMDISK_PREBUILT_BINARY=${ANDROID_BUILD_TOP}/stock/ramdisk/ramdisk.lz4 ${ANDROID_BUILD_TOP}/kernel_platform/build/android/prepare_vendor.sh sec ${TARGET_PRODUCT} || abort
    else
        env ${GKI_KERNEL_BUILD_OPTIONS} ${ANDROID_BUILD_TOP}/kernel_platform/build/android/prepare_vendor.sh sec ${TARGET_PRODUCT} || abort
    fi
}

build_zip() {
    echo "-----------------------------------------------"
    echo "Building AK3 zip..."
    echo "-----------------------------------------------"

    echo "Cleanup old images"
    if [ -f "${ANDROID_BUILD_TOP}/external/AnyKernel3/Image" ]; then
        rm -f \
            "${ANDROID_BUILD_TOP}/external/AnyKernel3/Image" \
            "${ANDROID_BUILD_TOP}/external/AnyKernel3/vendor_boot.img" \
            "${ANDROID_BUILD_TOP}/external/AnyKernel3/vendor_dlkm.img"
    fi

    echo "Copying kernel image binary"
    cp ${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}/dist/Image ${ANDROID_BUILD_TOP}/external/AnyKernel3/Image

    chmod -R +x prebuilts/

    mv ${DIST_DIR}/wlan.ko ${DIST_DIR}/qca_cld3_wlan.ko

    echo "Building vendor_boot.img"
    SCRIPT_DIR="${SCRIPT_DIR}" "${SCRIPT_DIR}/prebuilts/build_vendor_boot.sh" || abort
    mv ${ANDROID_BUILD_TOP}/release/vendor_boot.img ${ANDROID_BUILD_TOP}/external/AnyKernel3/vendor_boot.img

    echo "Building vendor_dlkm.img"
    SCRIPT_DIR="${SCRIPT_DIR}" "${SCRIPT_DIR}/prebuilts/build_vendor_dlkm.sh" || abort
    mv ${ANDROID_BUILD_TOP}/release/vendor_dlkm.img ${ANDROID_BUILD_TOP}/external/AnyKernel3/vendor_dlkm.img

    echo "Packing images with AnyKernel3"

    pushd "${ANDROID_BUILD_TOP}/external/AnyKernel3" > /dev/null

    version=$(grep '^CONFIG_LOCALVERSION=' "${ANDROID_BUILD_TOP}/${CUST_DEFCONFIG}" | cut -d'"' -f2 | sed 's/-'"${MODEL}"'.*//')
    version=${version:1}
    DATE=`date +"%d-%m-%Y_%H-%M-%S"`

    if [[ "$SUSFS_OPTION" == "y" ]]; then
        ZIPNAME="${version}${KVER}_${MODEL}_KSUN_SUSFS_OFFICIAL_${DATE}-$(git rev-parse --short=8 HEAD).zip"
    else
        ZIPNAME="${version}${KVER}_${MODEL}_KSUN_OFFICIAL_${DATE}-$(git rev-parse --short=8 HEAD).zip"
    fi

    zip -r9 "${ANDROID_BUILD_TOP}/release/zip/${ZIPNAME}" * -x ".git*" "README.md" "*placeholder" || abort
    popd > /dev/null
}

build_tar() {
    echo "-----------------------------------------------"
    echo "Building Odin Flashable tar..."
    echo "-----------------------------------------------"

    echo "Cleanup old images"
    if [ -f "${ANDROID_BUILD_TOP}/release/tar/boot.img" ]; then
        rm -f \
            "${ANDROID_BUILD_TOP}/release/tar/boot.img" \
            "${ANDROID_BUILD_TOP}/release/tar/vendor_boot.img"
    fi

    echo "Copying boot image"
    cp ${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}/dist/boot.img ${ANDROID_BUILD_TOP}/release/tar/boot.img

    chmod -R +x prebuilts/

    mv ${DIST_DIR}/wlan.ko ${DIST_DIR}/qca_cld3_wlan.ko

    echo "Building vendor_boot.img"
    SCRIPT_DIR="${SCRIPT_DIR}" "${SCRIPT_DIR}/prebuilts/build_vendor_boot.sh" || abort

    mv ${ANDROID_BUILD_TOP}/release/vendor_boot.img ${ANDROID_BUILD_TOP}/release/tar/vendor_boot.img

    echo "Compressing images"
    pushd "${ANDROID_BUILD_TOP}/release/tar" > /dev/null

    version=$(grep '^CONFIG_LOCALVERSION=' "${ANDROID_BUILD_TOP}/${CUST_DEFCONFIG}" | cut -d'"' -f2 | sed 's/-'"${MODEL}"'.*//')
    version=${version:1}
    DATE=`date +"%d-%m-%Y_%H-%M-%S"`

    if [[ "$SUSFS_OPTION" == "y" ]]; then
        TARNAME="${version}${KVER}_${MODEL}_KSUN_SUSFS_OFFICIAL_${DATE}-$(git rev-parse --short=8 HEAD).tar"
    else
        TARNAME="${version}${KVER}_${MODEL}_KSUN_OFFICIAL_${DATE}-$(git rev-parse --short=8 HEAD).tar"
    fi

    tar -cvf "${TARNAME}" boot.img vendor_boot.img || abort
    popd > /dev/null
}

BUILD_START=$(date +%s)

if [[ "$CLEAN_OPTION" == "y" ]]; then
    echo "-----------------------------------------------"
    echo "Cleaning up build environment..."
    echo "-----------------------------------------------"
    echo "Deleting out folder"
    echo "-----------------------------------------------"
    rm -rf "${ANDROID_BUILD_TOP}/out"
    echo "Deleting device folder"
    echo "-----------------------------------------------"
    rm -rf "${ANDROID_BUILD_TOP}/device"
    echo "Deleting builds in releases folder"
    echo "-----------------------------------------------"
    rm -f "${ANDROID_BUILD_TOP}/release/tar/"*
    rm -f "${ANDROID_BUILD_TOP}/release/zip/"*

    exit 0
fi

update_submodules
enable_susfs
set_localversion
build_kernel

if [[ -z "$RECOVERY" || -z "$ODIN" ]]; then
build_zip
fi

if [[ "$ODIN_OPTION" == "y" ]]; then
build_tar
fi

echo "-----------------------------------------------"

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

if [ "$BUILD_TIME" -ge 3600 ]; then
    printf "Build finished successfully! Build time: \033[1;32m%dh %dm %ds\033[0m\n" \
        $((BUILD_TIME / 3600)) \
        $(((BUILD_TIME % 3600) / 60)) \
        $((BUILD_TIME % 60))
elif [ "$BUILD_TIME" -ge 60 ]; then
    printf "Build finished successfully! Build time: \033[1;32m%dm %ds\033[0m\n" \
        $((BUILD_TIME / 60)) \
        $((BUILD_TIME % 60))
else
    printf "Build finished successfully! Build time: \033[1;32m%ds\033[0m\n" "$BUILD_TIME"
fi