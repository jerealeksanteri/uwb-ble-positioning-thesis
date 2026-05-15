#!/bin/bash
# Flash QANI firmware for a specific anchor
# Usage: ./flash_anchor.sh <anchor_id> [jlink_serial]
#
# Examples:
#   ./flash_anchor.sh 1              # Flash anchor 1 (single board connected)
#   ./flash_anchor.sh 2 760220584    # Flash anchor 2 to specific J-Link serial

set -e

ANCHOR_ID=${1:?Usage: ./flash_anchor.sh <1|2|3> [jlink_serial]}
SERIAL=${2:-}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEX="$SCRIPT_DIR/hex/UWB-Anchor-${ANCHOR_ID}.hex"

if [[ "$ANCHOR_ID" != "1" && "$ANCHOR_ID" != "2" && "$ANCHOR_ID" != "3" ]]; then
    echo "Error: ANCHOR_ID must be 1, 2, or 3"
    exit 1
fi

if [ ! -f "$HEX" ]; then
    echo "Error: $HEX not found. Run build_anchors.sh first."
    exit 1
fi

SERIAL_FLAG=""
if [ -n "$SERIAL" ]; then
    SERIAL_FLAG="-s $SERIAL"
fi

echo "=== Flashing UWB-Anchor-${ANCHOR_ID} ==="
echo "Hex file: $HEX"

nrfjprog --eraseall -f nrf52 $SERIAL_FLAG
nrfjprog --program "$HEX" --verify -f nrf52 $SERIAL_FLAG
nrfjprog --reset -f nrf52 $SERIAL_FLAG

echo ""
echo "=== UWB-Anchor-${ANCHOR_ID} flashed successfully ==="
