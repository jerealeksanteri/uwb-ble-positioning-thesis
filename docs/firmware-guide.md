# Firmware Guide

## Overview

The anchor firmware is based on **Qorvo DW3_QM33 SDK v1.1.1**, which provides the complete Nearby Interaction (NI) accessory protocol stack. The custom modifications are minimal:

- Unique BLE device names per anchor (`UWB-Anchor-1`, `-2`, `-3`)
- LED status indicators
- RTT debug logging

The firmware uses nRF5 SDK v17.1.0, FreeRTOS, and Nordic SoftDevice S140 v7.2.0 for BLE.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| CMake | 3.20+ | Build system |
| ARM GCC | 10.3-2021.10 | Cross-compiler for Cortex-M4F |
| Qorvo DW3_QM33 SDK | v1.1.1 | Firmware base (includes libniq, drivers, BLE stack) |
| nRF Command Line Tools | 10.x | `nrfjprog` for flashing |
| SEGGER J-Link Software | 7.x+ | J-Link driver for on-board debugger |

### Installation Paths

The build scripts expect these paths (configurable via environment variables):

```bash
# ARM GCC toolchain
/opt/gcc/gcc-arm-none-eabi-10.3-2021.10/

# Qorvo SDK (override with DW3_QM33_SDK env var)
~/Documents/DW3_QM33_SDK_1.1.1/
```

## Build

### Build All Anchors

```bash
cd firmware/anchor
./build_anchors.sh
```

This builds three firmware variants (`-DANCHOR_ID=1`, `2`, `3`) and places the hex files in `firmware/anchor/hex/`:

```
hex/
├── UWB-Anchor-1.hex
├── UWB-Anchor-2.hex
└── UWB-Anchor-3.hex
```

### Build a Single Anchor

The build script delegates to the SDK's build helper:

```bash
# Set SDK path if not in default location
export DW3_QM33_SDK=~/Documents/DW3_QM33_SDK_1.1.1/SDK/Firmware

# Build anchor 1 only
"$DW3_QM33_SDK/build_anchor.sh" 1
```

## Flash

### Flash a Specific Anchor

```bash
cd firmware/anchor
./flash_anchor.sh 1       # Flash anchor 1 (single board connected via USB)
./flash_anchor.sh 2 760220584  # Flash anchor 2 to specific J-Link serial
```

The flash script performs:
1. `nrfjprog --eraseall` — full chip erase
2. `nrfjprog --program` — write hex file with verification
3. `nrfjprog --reset` — restart the board

### Multiple Boards

If multiple DWM3001CDK boards are connected simultaneously, specify the J-Link serial number (printed on the board's J-Link OB sticker):

```bash
./flash_anchor.sh 1 760123456
./flash_anchor.sh 2 760234567
./flash_anchor.sh 3 760345678
```

Find connected J-Link serials with:
```bash
nrfjprog --ids
```

## Firmware Customization

### anchor_config.h

The only custom header file. Defines the BLE device name based on `ANCHOR_ID`:

```c
#if ANCHOR_ID == 1
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-1"
#elif ANCHOR_ID == 2
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-2"
#elif ANCHOR_ID == 3
  #define ANCHOR_DEVICE_NAME "UWB-Anchor-3"
#endif
```

### Source Files

| File | Purpose |
|------|---------|
| `main.c` | Entry point, FreeRTOS task setup, board initialization |
| `fira_niq.c` | NI protocol handler (libniq callbacks, UWB start/stop, disconnect cleanup) |
| `anchor_config.h` | Per-anchor compile-time configuration |
| `QANI-FreeRTOS.cmake` | CMake build configuration |
| `project_QANI.cmake` | CMake project definition |

### RTT Debug Logging

Debug output via SEGGER RTT (real-time transfer). View logs with:

```bash
JLinkRTTViewer
# or
JLinkExe -device nRF52833_xxAA -if SWD -speed 4000
> connect
> rtt start
```

Logging is enabled via `CONFIG_LOG ON` in `QANI-FreeRTOS.cmake`. Log output uses Qorvo `QLOG` macros.

## Troubleshooting

### J-Link Error -256

```
ERROR: nrfjprog --eraseall returned error -256
```

Non-fatal version mismatch between nrfjprog and J-Link firmware. Operations still succeed. Suppress by updating J-Link software to match nrfjprog version.

### Build Fails: SDK Not Found

Ensure `DW3_QM33_SDK` environment variable points to the correct path:

```bash
export DW3_QM33_SDK=~/Documents/DW3_QM33_SDK_1.1.1/SDK/Firmware
```

### Board Not Detected

1. Check USB connection (use data cable, not charge-only)
2. Verify J-Link driver: `nrfjprog --ids` should show the serial number
3. Try different USB port
4. Reset the board (press reset button)

### Firmware Flashed But No BLE Advertising

1. Verify correct hex file was flashed (check anchor ID)
2. Ensure full erase before programming (SoftDevice must be included in hex)
3. Check with nRF Connect mobile app for "UWB-Anchor-N" devices
