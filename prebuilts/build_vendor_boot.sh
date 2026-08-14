#!/bin/bash

# core variables
REPO_ROOT="${SCRIPT_DIR}"
LKM_TOOLS_DIR="${REPO_ROOT}/prebuilts/LKM_Tools"
KBUILD_PATH="${REPO_ROOT}/out/msm-waipio-waipio-gki/dist"
PKG_VENDOR_BOOT="${LKM_TOOLS_DIR}/02.prepare_vendor_boot_modules.sh"
BOOT_EDITOR_DIR="${REPO_ROOT}/prebuilts/vendor_boot_unpack"

# input variables for LKM_Tools
STAGING_DIR="${KBUILD_PATH}"
SYSTEM_MAP="${KBUILD_PATH}/System.map"
STRIP_TOOL="${REPO_ROOT}/kernel_platform/prebuilts/clang/host/linux-x86/clang-r596125/bin/llvm-strip"
MODULES_LIST="${LKM_TOOLS_DIR}/vendor_boot/modules_list.txt"
OEM_LOAD_FILE="${LKM_TOOLS_DIR}/vendor_boot/modules.load"
OUTPUT_DIR="${BOOT_EDITOR_DIR}/build/unzip_boot/root.1/lib/modules"

# 01. run LKM_Tools
# Documentation: ./02.prepare_vendor_boot_modules.sh <modules_list> <staging_dir> <oem_load_file> <system_map> <strip_tool> <output_dir>
package_modules() {
    mkdir -p "${OUTPUT_DIR}" && \
        "${PKG_VENDOR_BOOT}" \
            "${MODULES_LIST}" \
            "${STAGING_DIR}" \
            "${OEM_LOAD_FILE}" \
            "${SYSTEM_MAP}" \
            "${STRIP_TOOL}" \
            "${OUTPUT_DIR}"
}

# 02. unpack stock vendor boot image and copy modified fstab to boot erofs images
unpack_vendor_boot() {
    if [ ! -d "${BOOT_EDITOR_DIR}/build" ]; then
        cp "${REPO_ROOT}/stock/vendor_boot.img" "${BOOT_EDITOR_DIR}/vendor_boot.img" && \
            cd "${BOOT_EDITOR_DIR}" && \
            ./gradlew unpack && \
            cp "${REPO_ROOT}/stock/fstab.qcom" "${BOOT_EDITOR_DIR}/build/unzip_boot/root.1/first_stage_ramdisk/fstab.qcom"
    fi
}

# 03. build the vendor boot
build_vendor_boot() {
    cd "${BOOT_EDITOR_DIR}" && \
        ./gradlew pack && \
        mv vendor_boot.img "${REPO_ROOT}/release/vendor_boot.img" && \
        cd "${REPO_ROOT}"
        rm -rf "${BOOT_EDITOR_DIR}/build"
}

# main execution
{ unpack_vendor_boot && \
    package_modules && \
    build_vendor_boot
} || {
    echo "Error: Failed to build the vendor boot"
    exit 1
}
