#!/bin/bash

# core variables
REPO_ROOT="${SCRIPT_DIR}"
LKM_TOOLS_DIR="${REPO_ROOT}/prebuilts/LKM_Tools"
KBUILD_PATH="${REPO_ROOT}/out/msm-waipio-waipio-gki/dist"
AIT_DIR="${REPO_ROOT}/prebuilts/vendor_dlkm_unpack"
PKG_VENDOR_DLKM="${LKM_TOOLS_DIR}/03.prepare_vendor_dlkm.sh"

# input variables for LKM_Tools
STAGING_DIR="${KBUILD_PATH}"
SYSTEM_MAP="${KBUILD_PATH}/System.map"
STRIP_TOOL="${REPO_ROOT}/kernel_platform/prebuilts/clang/host/linux-x86/clang-r437112/bin/llvm-strip"
VENDOR_DLKM_MODULES_LIST="${LKM_TOOLS_DIR}/vendor_dlkm/modules_list.txt"
VENDOR_BOOT_MODULES_LIST="${LKM_TOOLS_DIR}/vendor_boot/modules_list.txt"
VENDOR_DLKM_MODULES_LOAD_FILE="${LKM_TOOLS_DIR}/vendor_dlkm/modules.load"
OUTPUT_DIR="${AIT_DIR}/EXTRACTED_IMAGES/extracted_vendor_dlkm"
MODULES_OUTPUT_DIR="${OUTPUT_DIR}/lib/modules"

# Function to replace a key=value pair in a config file
replace_config_value() {
    local file="$1"
    local var_name="$2"
    local new_value="$3"

    if [ ! -f "$file" ]; then
        echo "Error: Config file not found: $file"
        return 1
    fi
    sed -i "s|^\($var_name=\).*|\1$new_value|" "$file" 
}

# 01. unpack stock vendor_dlkm.img
unpack_vendor_dlkm() {
    if [ ! -d "${AIT_DIR}/EXTRACTED_IMAGES/extracted_vendor_dlkm" ]; then
        replace_config_value "${AIT_DIR}/CONFIGS/vendor_dlkm_unpack.conf" "INPUT_IMAGE" "${REPO_ROOT}/stock/vendor_dlkm.img" && \
        replace_config_value "${AIT_DIR}/CONFIGS/vendor_dlkm_unpack.conf" "EXTRACT_DIR" "${OUTPUT_DIR}" && \
        cd "${AIT_DIR}" && \
        sudo ./android_image_tools.sh --conf=${AIT_DIR}/CONFIGS/vendor_dlkm_unpack.conf
    fi
}

# 02. run LKM_Tools
# Documentation: ./03.prepare_vendor_dlkm.sh <modules_list> <staging_dir> <oem_load_file> <system_map> <strip_tool> <output_dir> <vendor_boot_list> <nh_dir> [blacklist_file]
package_modules() {
    mkdir -p "${MODULES_OUTPUT_DIR}" && \
        "${PKG_VENDOR_DLKM}" \
            "${VENDOR_DLKM_MODULES_LIST}" \
            "${STAGING_DIR}" \
            "${VENDOR_DLKM_MODULES_LOAD_FILE}" \
            "${SYSTEM_MAP}" \
            "${STRIP_TOOL}" \
            "${MODULES_OUTPUT_DIR}" \
            "${VENDOR_BOOT_MODULES_LIST}" \
            "" \
            ""
}

# 03. replace the config values
replace_config_values() {
    replace_config_value "${AIT_DIR}/CONFIGS/vendor_dlkm_repack.conf" "SOURCE_DIR" "${OUTPUT_DIR}" && \
    replace_config_value "${AIT_DIR}/CONFIGS/vendor_dlkm_repack.conf" "OUTPUT_IMAGE" "${REPO_ROOT}/prebuilts/vendor_dlkm_unpack/REPACKED_IMAGES/vendor_dlkm_repacked.img"
}

# 04. build vendor_dlkm.img
build_vendor_dlkm() {
    cd "${AIT_DIR}" && \
        sudo ./android_image_tools.sh --conf=${AIT_DIR}/CONFIGS/vendor_dlkm_repack.conf && \
        mv "${AIT_DIR}/REPACKED_IMAGES/vendor_dlkm_repacked.img" "${REPO_ROOT}/external/AnyKernel3/vendor_dlkm.img" && \
        rm -rf ${OUTPUT_DIR} && \
        cd "${REPO_ROOT}"
}

# main execution
{ unpack_vendor_dlkm && \
    package_modules && \
    replace_config_values && \
    build_vendor_dlkm
} || {
    echo "Error: Failed to build the vendor_dlkm"
    exit 1
}
