#!/bin/bash
set -e

# Initialize Submodules if they're not initialized

if [ -f .gitmodules ]; then
  UNINITIALIZED_SUBMODULES=$(git submodule status | grep '^-' || true)
  
  if [ -n "$UNINITIALIZED_SUBMODULES" ]; then
    echo "The following submodules are missing or uninitialized:"
    echo "$UNINITIALIZED_SUBMODULES"
    echo "Initializing and cloning submodules..."
    git submodule update --init --recursive
    if [ $? -eq 0 ]; then
      echo "Submodules initialized and cloned successfully."
    else
      echo "Failed to clone submodules. Please check your repository configuration."
      exit 1
    fi
  else
    echo "All submodules are already initialized."
  fi
else
  echo "No submodules found in this repository."
fi

# Available models
VALID_MODELS=("bloomxq" "c1q" "c2q" "f2q" "gts7l" "gts7lwifi" "gts7xl" "gts7xlwifi" "r8q" "x1q" "y2q" "z3q")

# Models that do support EUR region
EUR_MODELS=("r8q" "gts7l" "gts7lwifi" "gts7xl" "gts7xlwifi" "f2q" "bloomxq")

# Available regions
VALID_REGIONS=("eur" "kor" "chn" "usa")

# Prompt function for cleaner code
prompt() {
    echo "=============================================="
    echo "$1"
    echo "=============================================="
    shift
    for option in "$@"; do
        echo "$option"
    done
    echo "=============================================="
}

# Function to validate input
validate_choice() {
    local choice="$1"
    shift
    local valid_values=("$@")
    
    for value in "${valid_values[@]}"; do
        if [[ "$choice" == "$value" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Model selection
prompt "Which project do you want to build?" "${VALID_MODELS[@]}"
read -p " - Enter your choice: " model_choice
model_choice=$(echo "$model_choice" | tr '[:upper:]' '[:lower:]')

if ! validate_choice "$model_choice" "${VALID_MODELS[@]}"; then
    echo "Invalid model choice! Exiting."
    exit 1
fi

# Region selection
#prompt "Which region do you want to build? (Leave empty for default config)" "${VALID_REGIONS[@]}"
#read -p " - Enter your choice: " region_choice
#region_choice=$(echo "$region_choice" | tr '[:upper:]' '[:lower:]')

#if [[ -n "$region_choice" && ! $(validate_choice "$region_choice" "${VALID_REGIONS[@]}") ]]; then
#    echo "Invalid region choice! Exiting."
#    exit 1
#fi

# Check EUR region restriction
if [[ "$region_choice" == "eur" && " ${EUR_MODELS[*]} " =~ " $model_choice " ]]; then
    echo "=============================================="
    echo "Error: This project doesn't support the EUR region."
    echo "=============================================="
    exit 1
fi

# Yes/No prompt function
yes_no_prompt() {
    local var_name=$1
    local message=$2
    prompt "$message" "yes" "no (default)"
    read -p " - Enter your choice: " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$choice" == "y" || "$choice" == "yes" ]]; then
        eval "$var_name=true"
    else
        eval "$var_name=false"
    fi
}

yes_no_prompt "USE_SDCLANG" "Would you like to use Snapdragon LLVM (proprietary)?"
yes_no_prompt "INCLUDE_KSU" "Would you like to add SuperUser (KSU) support?"
yes_no_prompt "PERMISSIVE" "Would you like to force Selinux to permissive?"


echo "=============================================="
echo "Configuration Summary:"
echo "Model: $model_choice"
echo "Region: ${region_choice:-default}"
echo "Snapdragon LLVM: $USE_SDCLANG"
echo "SuperUser (KSU) Support: $INCLUDE_KSU"
echo "=============================================="

# Build paths. Must be defined before anything else
PRODUCT_OUT=out
KERNEL_DIR=$(pwd)
BUILD_ROOT_DIR=$KERNEL_DIR/..
KERNEL_OUT_DIR=$PRODUCT_OUT/obj/KERNEL_OBJ

# Ensure KERNEL_OUT_DIR exists
if ! [ -d "$KERNEL_OUT_DIR" ]; then
    echo "Creating output directory: $KERNEL_OUT_DIR"
    mkdir -p "$KERNEL_OUT_DIR" || { echo "Error: Failed to create KERNEL_OUT_DIR. Exiting."; exit 1; }
fi

# Target properties
MODEL=$model_choice
REGION=$region_choice
CHIPSET_NAME=kona
KERNEL_ARCH=arm64

# Kona platform now belongs to platform 11
export PROJECT_NAME="${MODEL}"
[ -z "${PLATFORM_VERSION}" ] && export PLATFORM_VERSION=11

# Target build parameters
KERNEL_DEFCONFIG="vendor/${CHIPSET_NAME}-sec-perf_defconfig"

if [ -n "$REGION" ]; then
    PROJECT_CONFIG="vendor/samsung/${MODEL}_${REGION}.config"
else
    PROJECT_CONFIG="vendor/samsung/${MODEL}.config"
fi

if [ "$INCLUDE_KSU" = true ]; then
    KSU_DEFCONFIG="vendor/ksu.config"
else
    KSU_DEFCONFIG="vendor/nonksu.config"
fi

if [ "$PERMISSIVE" = true ]; then
    SLNX_DEFCONFIG="vendor/permissive.config"
fi

# Set toolchain and build environment
if [ "$USE_SDCLANG" = true ]; then
    echo "Using Snapdragon LLVM"
    if [ ! -d "/opt/qcom/Qualcomm_Snapdragon_LLVM_ARM_Toolchain_OEM/19.0.0.0/bin" ]; then
        echo "Error: Snapdragon toolchain directory not found. Exiting."
        exit 1
    fi

    PATH="/opt/qcom/Qualcomm_Snapdragon_LLVM_ARM_Toolchain_OEM/19.0.0.0/bin:${PATH}"
    KERNEL_LLVM_BIN="/opt/qcom/Qualcomm_Snapdragon_LLVM_ARM_Toolchain_OEM/19.0.0.0/bin/clang"
    BUILD_CROSS_COMPILE="aarch64-linux-gnu-"
    CLANG_TRIPLE="aarch64-linux-gnu-"
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
else
    echo "Using AOSP LLVM"
    if [ ! -d "/home/atakan/lineage/prebuilts/clang/host/linux-x86/clang-r536225/bin" ] || [ ! -d "/opt/aosp/gas" ]; then
        echo "Error: AOSP toolchain directories not found. Exiting."
        exit 1
    fi

    PATH="/home/atakan/lineage/prebuilts/clang/host/linux-x86/clang-r536225/bin:/opt/aosp/gas:${PATH}"
    KERNEL_LLVM_BIN="/home/atakan/lineage/prebuilts/clang/host/linux-x86/clang-r536225/bin/clang"
    GAS_CROSS_COMPILE="/opt/aosp/gas/aarch64-linux-gnu-"
    GAS_CROSS_COMPILE_COMPAT="/opt/aosp/gas/arm-linux-gnueabi-"
fi

# Set kernel build environment variables
if [ "$USE_SDCLANG" = true ]; then
    KERNEL_MAKE_PARAM="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump OBJSIZE=llvm-size READELF=llvm-readelf HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld DTC_OVERLAY_TEST_EXT=$KERNEL_DIR/tools/ufdt_apply_overlay"
else
    KERNEL_MAKE_PARAM="LLVM=1 DTC_OVERLAY_TEST_EXT=$KERNEL_DIR/tools/ufdt_apply_overlay"
fi

# Get number of CPU cores for parallel builds
BUILD_JOB_NUMBER=$(grep -c processor /proc/cpuinfo)

FUNC_BUILD_KERNEL() {
    local __dts_dir="${KERNEL_OUT_DIR}/arch/${KERNEL_ARCH}/boot/dts"

    echo ""
    echo "=============================================="
    echo "Starting: FUNC_BUILD_KERNEL"
    echo "=============================================="
    echo "Build Info"
    echo "=============================================="
    echo "Project: $PROJECT_NAME"
    echo "Common config: $KERNEL_DEFCONFIG"
    echo "Project config: $PROJECT_CONFIG"
    echo "Extra included configs: "$KSU_DEFCONFIG $SLNX_DEFCONFIG""
    echo "Output directory: $PRODUCT_OUT"
    echo "=============================================="
    echo ""

    if [ "$USE_SDCLANG" = true ]; then
        # Using SDClang
        make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
            CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
            CC="$KERNEL_LLVM_BIN" \
            CLANG_TRIPLE="$CLANG_TRIPLE" \
            CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
            $KERNEL_DEFCONFIG \
            $PROJECT_CONFIG \
            $KSU_DEFCONFIG \
            $SLNX_DEFCONFIG

        make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" -j"$BUILD_JOB_NUMBER" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
            CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
            CC="$KERNEL_LLVM_BIN" \
            CLANG_TRIPLE="$CLANG_TRIPLE" \
            CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32"
    else
        # Using AOSP LLVM
        make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
            CROSS_COMPILE="$GAS_CROSS_COMPILE" \
            CROSS_COMPILE_COMPAT="$GAS_CROSS_COMPILE_COMPAT" \
            $KERNEL_DEFCONFIG \
            $PROJECT_CONFIG \
            $KSU_DEFCONFIG \
            $SLNX_DEFCONFIG \
            "vendor/lto.config"

        make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" -j"$BUILD_JOB_NUMBER" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
            CROSS_COMPILE="$GAS_CROSS_COMPILE" \
            CROSS_COMPILE_COMPAT="$GAS_CROSS_COMPILE_COMPAT"
    fi

    cat "$__dts_dir/vendor/qcom"/*.dtb > "$PRODUCT_OUT/dtb.img"

    # Remove compiled DTBO's after every single compilation
    rm -rf "$__dts_dir/samsung/*"

    cp "$KERNEL_OUT_DIR/arch/arm64/boot/dtbo.img" "$PRODUCT_OUT"

    rsync -cv "$KERNEL_OUT_DIR/arch/arm64/boot/Image" "$PRODUCT_OUT/Image"

    ls -al "$PRODUCT_OUT/Image"

    echo ""
    echo "================================="
    echo "Ending: FUNC_BUILD_KERNEL"
    echo "================================="
    echo ""
}

FUNC_BUILD_BOOTIMG() {
    BUILD_ENV="$KERNEL_DIR/build_env/WORK_DIR"
    TARGET="$KERNEL_DIR/build_env/$MODEL"
    BOOT_IMG_REPO="https://github.com/ata-kaner/r8q_archive/releases/download/stock_kernel/boot_r8q.img"

    if ! [ -d "$TARGET" ]; then
        mkdir -p "$TARGET" || { echo "Error: Failed to create target directory. Exiting."; exit 1; }
    fi

    if ! [ -f "$BUILD_ENV/boot.img" ]; then
        echo "Downloading stock boot image from $BOOT_IMG_REPO"
        curl -L -s -o "$BUILD_ENV/boot.img" "$BOOT_IMG_REPO" || { echo "Error: Failed to download boot.img. Exiting."; exit 1; }
    fi

    cd "$BUILD_ENV"

    ./magiskboot-x86 unpack boot.img

    cp "$KERNEL_DIR/$PRODUCT_OUT/dtb.img" ./dtb

    rsync -cv "$KERNEL_DIR/$PRODUCT_OUT/Image" ./kernel

    ./magiskboot-x86 repack boot.img "queen_$MODEL.img"

    if [ "$INCLUDE_KSU" != true ]; then
        rsync -cv "./queen_$MODEL.img" "$TARGET/boot.img"
    else
        rsync -cv "./queen_$MODEL.img" "$TARGET/boot_ksu.img"
    fi

    ./magiskboot-x86 cleanup

    rm "./queen_$MODEL.img"

    cp "$KERNEL_DIR/$PRODUCT_OUT/dtbo.img" ./dtbo.img
}


(
	FUNC_BUILD_KERNEL
    FUNC_BUILD_BOOTIMG
)
