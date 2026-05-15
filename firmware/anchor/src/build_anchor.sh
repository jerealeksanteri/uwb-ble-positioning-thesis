#!/bin/bash
# Build QANI firmware for a specific anchor ID
# Usage: ./build_anchor.sh <anchor_id>
#   anchor_id: 1, 2, or 3

set -e

ANCHOR_ID=${1:?Usage: ./build_anchor.sh <1|2|3>}

if [[ "$ANCHOR_ID" != "1" && "$ANCHOR_ID" != "2" && "$ANCHOR_ID" != "3" ]]; then
    echo "Error: ANCHOR_ID must be 1, 2, or 3"
    exit 1
fi

SDK="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SDK/Projects/FreeRTOS/QANI/DWM3001CDK"
BUILD="$SDK/BuildOutput/QANI/FreeRTOS/DWM3001CDK/Anchor-${ANCHOR_ID}"
TOOLCHAIN="$SDK/Projects/Common/cmakefiles/arm-none-eabi-gcc.cmake"

export PATH="/opt/gcc/gcc-arm-none-eabi-10.3-2021.10/bin:${PATH}"

echo "=== Building UWB-Anchor-${ANCHOR_ID} ==="

# Clean previous build
rm -rf "$BUILD"

# Configure
cmake -S "$SOURCE" \
    -B "$BUILD" \
    -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DMY_TARGET_SCRIPT="$SOURCE/project_QANI.cmake" \
    -DPROJECT_BASE="$SDK" \
    -DCOMMON_PATH="$SDK/Projects/Common/cmakefiles" \
    -DPROJECT_COMMON="$SDK/Projects/FreeRTOS/QANI/Common" \
    -DLIBS_PATH=Libs \
    -DCMAKE_BUILD_TYPE=Debug \
    -DANCHOR_ID="$ANCHOR_ID"

# Build
make -C "$BUILD" -j

echo ""
echo "=== Build complete: UWB-Anchor-${ANCHOR_ID} ==="
echo "Hex file: $BUILD/DWM3001CDK-QANI-FreeRTOS.hex"
