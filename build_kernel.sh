#!/bin/bash
# copy right by zetaxbyte
# you can rich me on telegram t.me/@zetaxbyte
# flags of proton clang

sudo apt-get install clang-format clang-tidy clang-tools clang clangd libc++-dev libc++1 libc++abi-dev libc++abi1 libclang-dev libclang1 liblldb-dev libllvm-ocaml-dev libomp-dev libomp5 lld lldb llvm-dev llvm-runtime llvm python3-clang -y

sudo apt-get install gcc-aarch64-linux-gnu bc -y

git clone https://gitlab.com/LeCmnGend/clang.git -b clang-18 --depth=1 $(pwd)/proton-clang



chmod +x scripts/crypto/fips_crypto_integrity.py

# change DEFCONFIG to you are defconfig name or device codename

DEFCONFIG="vendor/x1q_kor_singlex_defconfig"

# you can set you name or host name(optional)

export KBUILD_BUILD_USER="SudoMohamed"
export KBUILD_BUILD_HOST="🌱"

# do not modify TC_DIR and export PATCH it's been including with the proton-clang dir

TC_DIR="$(pwd)/proton-clang"

export PATH="$TC_DIR/bin:$PATH"
export CONFIG_NO_ERROR_ON_MISMATCH=y
export CONFIG_DEBUG_SECTION_MISMATCH=y
mkdir -p out
make O=out CC=clang ARCH=arm64 $DEFCONFIG

make O=out -j32 KCFLAGS=-w ARCH=arm64 CC=clang AR=llvm-ar NM=llvm-nm OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee log.txt
