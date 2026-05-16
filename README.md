# UWB/BLE Indoor Positioning System

Bachelor's thesis project: a 2D indoor positioning system using 3x Qorvo DWM3001CDK development boards (nRF52833 + DW3110 UWB) as anchors and an iPhone 16 Pro Max as the mobile tag. The iPhone's U2 chip ranges directly with the DW3110 via Apple's Nearby Interaction framework; BLE serves only as the control/configuration channel.

## Architecture

```
iPhone 16 Pro Max (Tag)                 DWM3001CDK x3 (Anchors)
+--------------------------+            +--------------------------+
| SwiftUI App              |            | Qorvo NI Firmware        |
|                          |            |                          |
| CoreBluetooth      <--- BLE --->      | BLE SoftDevice (S140)    |
|   scan, connect, GATT    | (config)  |   advertise, GATT NI svc |
|                          |            |                          |
| NearbyInteraction  <--- UWB --->      | DW3110 UWB IC            |
|   NISession per anchor   | (ranging) |   NI responder mode      |
|                          |            |                          |
| TrilaterationEngine      |            | Config: anchor_id, (x,y) |
|   3 distances -> (x,y)   |            +--------------------------+
+--------------------------+
```

The system achieves ~12 mm ranging precision (std dev) and ~7 cm mean ranging bias under line-of-sight conditions.

## Repository Structure

```
uwb-ble-positioning-thesis/
├── firmware/anchor/         Anchor firmware (C, CMake + ARM GCC)
│   ├── src/                 Source files (main.c, fira_niq.c, anchor_config.h)
│   ├── hex/                 Pre-built firmware binaries
│   ├── build_anchors.sh     Build all 3 anchor variants
│   └── flash_anchor.sh      Flash a specific anchor
├── ios-app/                 iOS SwiftUI application
│   └── UWBPositioning/      Xcode project (MVVM architecture)
├── measurements/            Calibration data and analysis scripts
│   ├── anchor-calibration/  Per-anchor distance calibration CSVs
│   └── calibration.py       Calibration analysis script
├── docs/                    Detailed documentation
│   ├── architecture.md      System architecture and data flow
│   ├── hardware-setup.md    Physical deployment guide
│   ├── firmware-guide.md    Build, flash, and customize firmware
│   ├── ios-app-guide.md     iOS app build and usage
│   └── calibration.md       Calibration procedure
├── IMPLEMENTATION_PLAN.md   10-phase implementation roadmap
└── STATE.md                 Current progress tracker
```

## Quick Start

### Hardware Requirements

- 3x [Qorvo DWM3001CDK](https://www.qorvo.com/products/p/DWM3001CDK) development boards
- iPhone 16 Pro Max (or any iPhone with U2 UWB chip, iOS 17.0+)
- SEGGER J-Link (on-board on DWM3001CDK)
- USB cables for power and programming

### Firmware

```bash
# Prerequisites: CMake, ARM GCC 10.3, Qorvo DW3_QM33 SDK v1.1.1, nRF Command Line Tools

# Build all 3 anchor firmware variants
cd firmware/anchor && ./build_anchors.sh

# Flash a specific anchor (1, 2, or 3)
./flash_anchor.sh 1
```

See [docs/firmware-guide.md](docs/firmware-guide.md) for detailed instructions.

### iOS App

Open `ios-app/UWBPositioning.xcodeproj` in Xcode, select a physical iPhone target (iOS 17.0+), and build & run. NearbyInteraction requires real hardware — the simulator is not supported.

See [docs/ios-app-guide.md](docs/ios-app-guide.md) for detailed instructions.

### Calibration

After deploying anchors, calibrate per-anchor distance offsets:

```bash
# Analyze calibration measurements (collected via the app's Measure tab)
python3 measurements/calibration.py
```

See [docs/calibration.md](docs/calibration.md) for the full procedure.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, data flow, algorithms |
| [Hardware Setup](docs/hardware-setup.md) | Board placement and physical deployment |
| [Firmware Guide](docs/firmware-guide.md) | Build, flash, and customize anchor firmware |
| [iOS App Guide](docs/ios-app-guide.md) | Build, run, and use the positioning app |
| [Calibration](docs/calibration.md) | Distance calibration procedure |

## Technology Stack

| Component | Technology |
|-----------|------------|
| Anchor MCU | nRF52833 (Cortex-M4F) |
| Anchor UWB | Qorvo DW3110 |
| Anchor firmware SDK | Qorvo DW3_QM33 SDK v1.1.1 + nRF5 SDK v17.1.0 |
| Anchor RTOS | FreeRTOS |
| Anchor BLE | Nordic SoftDevice S140 v7.2.0 |
| NI protocol | Qorvo `libniq` (pre-built library) |
| iOS target | iOS 17.0+ |
| iOS language | Swift 5.9 + SwiftUI |
| iOS frameworks | NearbyInteraction, CoreBluetooth |
| Data analysis | Python 3 (pandas, numpy, matplotlib) |

## License

MIT
