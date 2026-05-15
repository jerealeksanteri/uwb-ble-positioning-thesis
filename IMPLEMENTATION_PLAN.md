# UWB/BLE Indoor Positioning System - Implementation Plan

## Context

Bachelor's thesis project: build a 2D indoor positioning system using 3x DWM3001CDK boards (nRF52833 + DW3110) as UWB anchors and an iPhone 16 Pro Max as the mobile tag. The iPhone's U2 chip can range **directly** with the DW3110 via Apple's Nearby Interaction framework — BLE serves only as the control/config channel.

**Key architecture decision:** Use **Qorvo's official DW3_QM33 SDK v1.1.1** (not nRF Connect SDK + community driver). The SDK includes the complete Nearby Interaction accessory protocol (`libniq`), DW3110 driver, BLE GATT NI service, and a working iOS sample app. Implementing the NI protocol from scratch would be prohibitively complex for a thesis timeline.

> **Trade-off:** The Qorvo SDK uses nRF5 SDK v17.1.0 + FreeRTOS + SEGGER Embedded Studio (not Zephyr/nRF Connect SDK v3.2.2). This is acceptable — the thesis is about the positioning system, not the RTOS.

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

---

## Phase 1: Development Environment Setup & Smoke Test (3-5 days)

### Goal
Get toolchain working, flash pre-built firmware, verify hardware with Qorvo's own iOS app.

### Steps

1. **Install SEGGER Embedded Studio** (macOS, free for Nordic dev)
2. **Install nRF5 SDK v17.1.0** — extract to `~/nRF5_SDK_17.1.0/`
3. **Install nRF Command Line Tools** — provides `nrfjprog` for flashing
4. **Install SEGGER J-Link Software** — DWM3001CDK has on-board J-Link OB
5. **Download Qorvo DW3_QM33 SDK v1.1.1** from [qorvo.com/products/p/DWM3001CDK](https://www.qorvo.com/products/p/DWM3001CDK) (Evaluation Tools tab)
6. **Download Qorvo Nearby Interaction package v3.0** (same page)
7. **Flash pre-built NI firmware** to one board:
   ```bash
   nrfjprog --eraseall -f nrf52
   nrfjprog --program Binaries/DWM3001CDK-QANI-FreeRTOS_full_QNI_3_0_0.hex --verify -f nrf52
   nrfjprog --reset -f nrf52
   ```
8. **Install "Qorvo Nearby Interaction" from App Store** on iPhone
9. **Verify**: Qorvo app discovers the board, connects, shows UWB distance
10. **Repeat** for all 3 boards to confirm hardware is functional
11. **Build from source**: open `.emProject` in SEGGER ES, configure SDK paths, build, flash, verify behavior matches pre-built

### Verification
- [x] All 3 boards flash and run pre-built NI firmware
- [x] Qorvo iOS app shows real-time distance to each board
- [x] Source-built firmware compiles and behaves identically

---

## Phase 2: Anchor Firmware — BLE Advertising & Anchor Identity (5-7 days)

### Goal
Customize the Qorvo NI firmware so each anchor advertises with a unique BLE name and identifier.

### Key files to modify (inside Qorvo SDK structure, copied to repo)
- `firmware/anchor/src/main.c` — entry point (derived from `ni_app.c` + `controlTask`)
- `firmware/anchor/src/anchor_config.h` — `ANCHOR_ID` define, position constants, device name
- `firmware/anchor/src/ble_advertising_custom.c` — custom BLE advertising name

### Steps

1. **Study Qorvo NI firmware source** — understand `ni_app.c`, `ni_ble.c`, `ni_uwb.c`, GATT service registration, FreeRTOS task structure
2. **Create `anchor_config.h`** with per-anchor config:
   ```c
   #ifndef ANCHOR_ID
   #error "ANCHOR_ID must be defined (1, 2, or 3)"
   #endif
   #if ANCHOR_ID == 1
     #define DEVICE_NAME "UWB-Anchor-1"
   #elif ANCHOR_ID == 2
     #define DEVICE_NAME "UWB-Anchor-2"
   #elif ANCHOR_ID == 3
     #define DEVICE_NAME "UWB-Anchor-3"
   #endif
   ```
3. **Modify BLE advertising** to use `DEVICE_NAME` via `sd_ble_gap_device_name_set()`
4. **Create 3 build configurations** in SEGGER project: `Anchor-1`, `Anchor-2`, `Anchor-3` with `-DANCHOR_ID=1/2/3`
5. **Add LED status indicators**: advertising (blink), connected (solid), ranging (fast blink), error (solid red)
6. **Add RTT debug logging** via `SEGGER_RTT_printf` for all state transitions
7. **Copy relevant source files into repo** under `firmware/anchor/`

### Verification
- [ ] nRF Connect mobile app sees 3 distinct "UWB-Anchor-X" devices
- [ ] GATT service discovery shows NI service UUID
- [ ] RTT logs show BLE events (connect/disconnect/read/write)

---

## Phase 3: Anchor Firmware — UWB & Full NI Protocol (5-7 days)

### Goal
Complete firmware with DW3110 initialization, NI responder mode, and the full BLE+UWB data exchange flow.

### Key files
- `firmware/anchor/src/main.c` — full init sequence: board -> SPI -> DW3110 -> NI lib -> BLE -> advertise
- NI library callbacks: `ni_on_config_read()`, `ni_on_shareable_received()`, `ni_on_ranging_complete()`

### Data flow on the anchor
```
IDLE -> BLE_CONNECTED -> CONFIG_SENT (iPhone reads GATT)
     -> SHAREABLE_RECEIVED (iPhone writes GATT) -> UWB_RANGING
     -> (timeout/disconnect) -> IDLE
```

### Steps

1. **Verify DW3110 SPI communication** — read device ID register
2. **Initialize NI library** (`niq_init`) — generates 38-byte Accessory Configuration Data
3. **Verify GATT characteristic** contains valid config data (readable from nRF Connect app)
4. **Implement shareable config write handler** — passes data to NI library, triggers UWB responder mode
5. **Flash all 3 boards** with respective anchor configs
6. **Test with Qorvo iOS app** — confirm all 3 range simultaneously

### Verification
- [ ] DW3110 initializes (device ID read succeeds)
- [ ] NI library generates valid 38-byte config data
- [ ] Single anchor does end-to-end ranging with Qorvo iOS app
- [ ] All 3 anchors range simultaneously

---

## Phase 4: iOS App — Project Setup & CoreBluetooth (5-7 days)

### Goal
Create the Xcode project, implement BLE scanning/connection, read NI config data from anchors.

### File structure
```
ios-app/UWBPositioning/
  UWBPositioningApp.swift
  Models/
    Anchor.swift                  # AnchorConfig (id, name, position), AnchorState
    Position.swift                # CGPoint-based 2D position
  Services/
    BluetoothManager.swift        # CBCentralManager, scan, connect, GATT R/W
    NearbyInteractionManager.swift
    TrilaterationEngine.swift
    DataExportService.swift       # CSV export for thesis measurements
  Views/
    ContentView.swift             # Tab view (floor plan, anchor list, settings)
    FloorPlanView.swift           # 2D canvas with anchors + position dot
    AnchorListView.swift          # Anchor status, distances
    SettingsView.swift            # Anchor position config
  ViewModels/
    PositioningViewModel.swift    # Coordinates BLE, NI, trilateration
  Utils/
    Constants.swift               # BLE UUIDs, default anchor positions
```

### Steps

1. **Create Xcode project** — SwiftUI, iOS 17.0+, bundle ID `com.jereniemi.uwb-positioning`
2. **Configure Info.plist** — `NSNearbyInteractionUsageDescription`, `NSBluetoothAlwaysUsageDescription`, background modes (BLE + NI)
3. **Enable capabilities** — Nearby Interaction, Background Modes
4. **Implement `BluetoothManager`**:
   - `CBCentralManager` scanning for NI service UUID
   - Filter peripherals by name prefix "UWB-Anchor-"
   - Connect, discover services/characteristics
   - Read Accessory Configuration Data characteristic
   - Write Shareable Configuration Data characteristic
5. **Implement `Anchor` model** and `AnchorListView` showing discovered/connected anchors
6. **Define NI GATT UUIDs** in `Constants.swift` (must match firmware)

### NI GATT Service UUIDs (from Apple NI Accessory Protocol Spec)
```swift
static let niService = CBUUID(string: "15171523-4947-11E9-8646-D663BD873D93")
static let accessoryConfigData = CBUUID(string: "15171524-4947-11E9-8646-D663BD873D93")
static let accessoryTx = CBUUID(string: "15171525-4947-11E9-8646-D663BD873D93")
static let accessoryRx = CBUUID(string: "15171526-4947-11E9-8646-D663BD873D93")
```

### Verification
- [ ] App builds and runs on iPhone 16 Pro Max
- [ ] BLE scan discovers all 3 anchors by name
- [ ] BLE connection + GATT discovery succeeds
- [ ] Accessory Config Data (38 bytes) is read successfully
- [ ] No permission issues

---

## Phase 5: iOS App — Nearby Interaction Sessions & Ranging (5-7 days)

### Goal
Create `NISession` per anchor, exchange config data over BLE, receive real-time distance measurements.

### Key file
- `Services/NearbyInteractionManager.swift`

### Steps

1. **Implement `NearbyInteractionManager`** with one `NISession` per anchor
2. **Create `NINearbyAccessoryConfiguration`** from accessory config data + `CBPeripheral.identifier`
3. **Handle `session(_:didGenerateShareableConfigurationData:for:)` delegate** — immediately write data to anchor via BLE GATT
4. **Handle `session(_:didUpdate:)` delegate** — extract `distance` and `direction` from `NINearbyObject`
5. **Handle session timeout/suspension** — re-run session with cached config
6. **Wire up `PositioningViewModel`** — BLE config received triggers NI session start; distance updates flow to trilateration
7. **Test single anchor** — verify full pipeline: scan -> connect -> config exchange -> UWB ranging -> distance displayed
8. **Test all 3 anchors simultaneously** — verify concurrent NISessions

### Critical timing note
The Shareable Configuration Data must be sent to the anchor within ~2 seconds of the delegate callback, or the session times out. Minimize BLE write latency.

### Verification
- [ ] Single anchor shows real-time distance (~10-30 Hz updates)
- [ ] Direction vector received (may be nil depending on orientation)
- [ ] 3 anchors range simultaneously with concurrent NISessions
- [ ] Session recovers from timeout/reconnection

---

## Phase 6: iOS App — Trilateration & Floor Plan UI (5-7 days)

### Goal
Compute 2D position from 3 distances, display on a floor plan view with anchor markers.

### Key files
- `Services/TrilaterationEngine.swift`
- `Views/FloorPlanView.swift`
- `Services/PositionFilter.swift` (moving average for smoothing)

### Trilateration algorithm
Linear least-squares: subtract first circle equation from the others to get `Ax = b`, solve via normal equations `x = (A^T A)^{-1} A^T b`. With 3 anchors this gives a 2x2 system with exact solution.

### Steps

1. **Implement `TrilaterationEngine.computePosition()`** — least-squares 2D trilateration
2. **Unit test with synthetic data** — known anchor positions + distances -> verify correct (x,y)
3. **Implement `PositionFilter`** — moving average (window=5) to reduce jitter
4. **Implement `FloorPlanView`** — SwiftUI Canvas/GeometryReader:
   - Grid background with meter scale
   - Anchor markers (triangles) at known positions with distance labels
   - Tag position (blue dot) at computed position
   - Optional: range circles for debug visualization
5. **Implement `AnchorListView`** — list of anchors with BLE status, UWB status, current distance
6. **Wire `PositioningViewModel`** — distance updates (throttled 100ms) trigger trilateration -> UI update
7. **Implement weighted trilateration variant** — weight inversely by distance squared (closer anchors more trusted)

### Verification
- [ ] Trilateration correct with synthetic test values
- [ ] Floor plan renders anchors and position dot
- [ ] Real-time position tracking with all 3 anchors
- [ ] Position filter reduces visible jitter

---

## Phase 7: System Integration & Single-Anchor Validation (3-5 days)

### Goal
End-to-end validation of the complete custom stack (not Qorvo's app) with one anchor.

### Steps

1. **Controlled test**: one anchor at a table, iPhone at known distances (0.5, 1, 2, 3, 5, 7, 10 m)
2. **Record 100 samples per distance** — calculate mean, std dev, min, max
3. **Implement `DataExportService`** — export measurements as CSV with columns: `timestamp, anchor_id, true_distance, measured_distance, dir_x, dir_y, dir_z`
4. **Debug common issues** (reference table):

   | Symptom | Likely Cause |
   |---------|-------------|
   | No BLE devices found | Wrong service UUID or firmware not advertising |
   | NISession config error | Invalid accessory config data format |
   | No distance after config | Shareable data sent too slowly (>2s) |
   | Erratic distances | Multipath / antenna obstruction |

### Verification
- [ ] Full pipeline works end-to-end with custom app
- [ ] Distance accuracy within +/- 10 cm at < 5m (LOS)
- [ ] CSV export works and contains valid data

---

## Phase 8: Multi-Anchor Positioning & Calibration (7-10 days)

### Goal
Deploy all 3 anchors, achieve 2D positioning, calibrate antenna delays, measure accuracy on a test grid.

### Anchor placement
```
    Anchor 3 (2.5, 4.0)
         *
        / \
       /   \
      *-----*
  A1 (0,0)  A2 (5,0)
```
Non-collinear triangle, same height (~1.2m), clear LOS to measurement area.

### Steps

1. **Deploy 3 anchors** — measure positions with tape measure (cm precision)
2. **Update anchor positions** in iOS app settings / `Constants.swift`
3. **Connect to all 3 and verify simultaneous ranging**
4. **Antenna delay calibration**:
   - Place iPhone at exactly 2.000m from each anchor individually
   - Record 60s of measurements
   - Calculate offset: `mean(measured) - 2.000`
   - Adjust in firmware: `dwt_settxantennadelay()` / `dwt_setrxantennadelay()`
   - Or apply offset in iOS app as distance correction
5. **Test grid measurement** (12 points):
   ```
   (1,1) (2,1) (3,1) (4,1)
   (1,2) (2,2) (3,2) (4,2)
   (1,3) (2,3) (3,3) (4,3)
   ```
   200 samples per point, record true (x,y) and computed (x,y)
6. **Calculate positioning error** = sqrt((x_true - x_comp)^2 + (y_true - y_comp)^2)
7. **Implement GDOP analysis** — how anchor geometry affects accuracy

### Verification
- [ ] All 3 anchors range simultaneously
- [ ] 2D position displayed on floor plan in real-time
- [ ] Position error < 30 cm at most LOS test points
- [ ] Calibration reduces systematic bias

---

## Phase 9: Measurements & Thesis Data Collection (7-10 days)

### Goal
Run structured measurement campaigns, analyze data, generate thesis figures.

### Experiments

| # | Experiment | Samples | Key metric |
|---|-----------|---------|------------|
| 1 | Distance accuracy (LOS) | 200/distance x 9 distances | Mean error, std dev |
| 2 | Distance accuracy (NLOS) | 200/distance x 5 distances | LOS vs NLOS comparison |
| 3 | 2D positioning accuracy | 200/point x 12 points | CEP50, CEP95 |
| 4 | Update rate & latency | Timestamps | Hz, time-to-first-fix |
| 5 | Anchor geometry effect | 2 placements x 12 points | GDOP vs error correlation |

### File structure
```
measurements/
  raw_data/           # CSV exports from iOS app
  scripts/
    analyze_distance.py
    analyze_position.py
    plot_floor_plan.py
    gdop_analysis.py
  results/
    figures/           # Plots for thesis
```

### Key thesis figures
1. Distance error vs. true distance (scatter + regression line)
2. CDF of distance error
3. 2D scatter plot: true vs. measured positions
4. CEP circles at each test point
5. GDOP heatmap over floor area
6. Time series of position at a stationary point
7. LOS vs. NLOS box plot comparison

---

## Phase 10: Documentation & Thesis Writing Support (5-7 days)

### Steps

1. **Update `README.md`** — full project description, setup instructions, flash guide, iOS app build guide
2. **Create `docs/` content** — system architecture diagram, anchor placement diagram, wiring/connection notes
3. **Thesis sections** to write (beyond code):
   - Theory: UWB TWR, BLE, NI accessory protocol, trilateration math
   - System design: architecture decisions (Qorvo SDK choice, direct ranging vs board-to-board)
   - Implementation: firmware structure, iOS app architecture, algorithm details
   - Results: all measurement data with statistical analysis
   - Discussion: error sources (multipath, NLOS, clock drift, GDOP), limitations, future work

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| Qorvo SDK doesn't build on macOS | SEGGER ES supports macOS; fallback: Windows VM |
| NI protocol version mismatch (iOS 18/19 vs SDK) | Test with Qorvo's own iOS app first to isolate firmware vs app issues |
| 3 concurrent NISessions unstable | Fallback: round-robin ranging (connect/range/disconnect per anchor) |
| Accuracy worse than expected | This is a thesis finding, not failure — document and discuss error sources |
| nRF Connect SDK v3.2.2 not used | Document the Qorvo SDK choice in thesis; note Zephyr port as future work |

## Technology Stack Summary

| Component | Choice |
|-----------|--------|
| Anchor firmware SDK | Qorvo DW3_QM33 SDK v1.1.1 + nRF5 SDK v17.1.0 |
| Anchor RTOS | FreeRTOS |
| Anchor IDE | SEGGER Embedded Studio |
| Anchor BLE | Nordic SoftDevice S140 v7.2.0 |
| Anchor NI protocol | Qorvo `libniq` (pre-built) |
| iOS minimum target | iOS 17.0 |
| iOS language | Swift + SwiftUI |
| iOS frameworks | NearbyInteraction, CoreBluetooth |
| Data analysis | Python 3 (matplotlib, numpy, pandas) |
