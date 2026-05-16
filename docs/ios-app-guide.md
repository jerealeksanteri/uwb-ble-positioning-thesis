# iOS App Guide

## Overview

The iOS app (`UWBPositioning`) is a SwiftUI application that:

1. Discovers and connects to UWB anchors via BLE
2. Establishes NearbyInteraction sessions for UWB ranging
3. Computes 2D position via trilateration
4. Displays real-time position on a floor plan
5. Records measurements and exports CSV data for analysis

## Prerequisites

| Requirement | Details |
|-------------|---------|
| macOS | With Xcode installed |
| Xcode | 15.0+ (Swift 5.9, iOS 17.0 SDK) |
| iPhone | With U2 UWB chip (iPhone 11 or newer) |
| Apple Developer account | Required for NearbyInteraction entitlement |
| Physical device | Simulator does not support NearbyInteraction or CoreBluetooth |

## Build & Run

1. Open `ios-app/UWBPositioning.xcodeproj` in Xcode
2. Select your physical iPhone as the run destination
3. Set the development team in Signing & Capabilities
4. Build and run (Cmd+R)

The app requires these capabilities (already configured in the project):
- Nearby Interaction
- Background Modes (BLE + NI)
- Bluetooth Always usage description

## App Tabs

The app has four tabs:

### Floor Plan

Real-time 2D visualization of the positioning system:
- Grid background with meter-scale labels
- Anchor markers (triangles) at configured positions — purple when ranging, gray when disconnected
- Live distance labels above ranging anchors
- Tag position (blue dot) — computed position with smoothing
- Status overlay showing coordinates and HDOP value

### Anchors

List of discovered and connected anchors with:
- Anchor name (BLE device name)
- Connection state (discovered / connected / ranging)
- RSSI signal strength
- Current distance (when ranging)
- Connect/disconnect controls

### Measure

Data recording for calibration and accuracy measurement:

**Distance mode:**
- Select an anchor and set the true distance
- Record N samples (configurable, default 60)
- Shows live distance, mean, std dev, min/max statistics
- Export to CSV for analysis

**Position mode:**
- Set true (x, y) position
- Records computed positions with HDOP and per-anchor distances
- Shows mean position error, CEP50, CEP95 statistics
- Export to CSV for analysis

### Settings

System configuration:

- **Anchor Positions** — X, Y coordinates for each anchor (meters)
- **Calibration Offsets** — per-anchor distance correction (meters)
- **Trilateration** — weighted/unweighted toggle, current HDOP display
- **Reset to Defaults** — restore factory anchor positions

Settings persist across app launches (stored in UserDefaults).

## CSV Export Formats

### Distance CSV

Exported from Measure tab (Distance mode):

```
timestamp,anchor_id,true_distance,measured_distance,dir_x,dir_y,dir_z
2026-05-16T11:35:54.332Z,1,0.500,0.5198,,,
```

| Column | Description |
|--------|-------------|
| timestamp | ISO 8601 UTC timestamp |
| anchor_id | Anchor identifier (1, 2, or 3) |
| true_distance | Ground truth distance (meters) |
| measured_distance | UWB measured distance (meters) |
| dir_x, dir_y, dir_z | Direction vector components (often empty — requires AoA support) |

### Position CSV

Exported from Measure tab (Position mode):

```
timestamp,true_x,true_y,computed_x,computed_y,filtered_x,filtered_y,hdop,d1,d2,d3
2026-05-16T12:00:01.123Z,1.0,2.0,1.05,2.03,1.04,2.02,1.5,1.12,2.35,3.01
```

| Column | Description |
|--------|-------------|
| timestamp | ISO 8601 UTC timestamp |
| true_x, true_y | Ground truth position (meters) |
| computed_x, computed_y | Raw trilateration result (meters) |
| filtered_x, filtered_y | Position after moving average filter |
| hdop | Horizontal Dilution of Precision |
| d1, d2, d3 | Calibrated distances to anchors 1, 2, 3 |

## Workflow

### First-Time Setup

1. Flash firmware to all 3 anchors (see [firmware-guide.md](firmware-guide.md))
2. Power on anchors (USB)
3. Launch the app — anchors appear in the Anchors tab
4. Tap each anchor to connect — ranging starts automatically
5. Go to Settings tab — configure anchor X, Y positions (measure with tape)
6. Verify floor plan shows correct anchor positions and live position dot

### Calibration

1. Go to Measure tab → Distance mode
2. For each anchor: record samples at known distances
3. Export CSVs and run `calibration.py` (see [calibration.md](calibration.md))
4. Enter suggested offsets in Settings → Distance Calibration Offsets

### Data Collection

1. Set up your measurement grid (mark points on floor)
2. Go to Measure tab → Position mode
3. Stand at each point, enter true (x, y), record samples
4. Export CSV after each point
5. Analyze with Python scripts in `measurements/`
