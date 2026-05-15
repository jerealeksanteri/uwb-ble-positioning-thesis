#!/bin/bash
# Build QANI firmware for all 3 UWB anchors
# Usage: ./build_anchors.sh
#
# Prerequisites:
#   - ARM GCC 10.3 toolchain at /opt/gcc/gcc-arm-none-eabi-10.3-2021.10/
#   - CMake installed
#   - Qorvo DW3_QM33 SDK extracted at ~/Documents/DW3_QM33_SDK_1.1.1/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK="${DW3_QM33_SDK:-$HOME/Documents/DW3_QM33_SDK_1.1.1/SDK/Firmware}"
HEX_DIR="$SCRIPT_DIR/hex"

mkdir -p "$HEX_DIR"

for ANCHOR_ID in 1 2 3; do
    echo ""
    echo "========================================"
    echo "  Building UWB-Anchor-${ANCHOR_ID}"
    echo "========================================"
    echo ""

    "$SDK/build_anchor.sh" "$ANCHOR_ID"

    BUILD="$SDK/BuildOutput/QANI/FreeRTOS/DWM3001CDK/Anchor-${ANCHOR_ID}"
    cp "$BUILD/DWM3001CDK-QANI-FreeRTOS.hex" "$HEX_DIR/UWB-Anchor-${ANCHOR_ID}.hex"

    echo "Copied to $HEX_DIR/UWB-Anchor-${ANCHOR_ID}.hex"
done

echo ""
echo "========================================"
echo "  All 3 anchors built successfully"
echo "========================================"
ls -la "$HEX_DIR"/*.hex
