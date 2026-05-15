# Project State Tracker

> This file tracks the current implementation state of the UWB/BLE positioning system.
> Updated as work progresses through each phase.

---

## Current Phase: Phase 1 — Development Environment Setup & Smoke Test

## Overall Progress

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Dev Environment Setup & Smoke Test | NOT STARTED | |
| 2. Anchor Firmware — BLE & Identity | NOT STARTED | Blocked by Phase 1 |
| 3. Anchor Firmware — UWB & NI Protocol | NOT STARTED | Blocked by Phase 2 |
| 4. iOS App — Project Setup & CoreBluetooth | NOT STARTED | Blocked by Phase 1 |
| 5. iOS App — NI Sessions & Ranging | NOT STARTED | Blocked by Phase 3, 4 |
| 6. iOS App — Trilateration & UI | NOT STARTED | Blocked by Phase 5 |
| 7. System Integration & Single-Anchor Test | NOT STARTED | Blocked by Phase 6 |
| 8. Multi-Anchor Positioning & Calibration | NOT STARTED | Blocked by Phase 7 |
| 9. Measurements & Thesis Data Collection | NOT STARTED | Blocked by Phase 8 |
| 10. Documentation & Thesis Writing | NOT STARTED | Ongoing alongside other phases |

---

## Phase 1: Dev Environment Setup & Smoke Test

- [x] SEGGER Embedded Studio installed
- [x] nRF5 SDK v17.1.0 downloaded and extracted
- [x] nRF Command Line Tools installed (`nrfjprog` available)
- [x] SEGGER J-Link Software installed
- [x] Qorvo DW3_QM33 SDK v1.1.1 downloaded
- [x] Qorvo Nearby Interaction package v3.0 downloaded
- [x] Pre-built NI firmware flashed to board 1
- [x] Pre-built NI firmware flashed to board 2
- [x] Pre-built NI firmware flashed to board 3
- [x] Qorvo NI iOS app installed on iPhone
- [x] Qorvo app shows distance to board 1
- [x] Qorvo app shows distance to board 2
- [x] Qorvo app shows distance to board 3
- [x] Source build compiles in SEGGER ES
- [x] Source-built firmware behaves identically to pre-built

## Phase 2: Anchor Firmware — BLE & Identity

- [ ] Qorvo NI firmware source code studied and understood
- [ ] `anchor_config.h` created with ANCHOR_ID defines
- [ ] BLE advertising modified with unique device names
- [ ] 3 build configurations created in SEGGER project
- [ ] LED status indicators implemented
- [ ] RTT debug logging added
- [ ] Source files copied into `firmware/anchor/` in repo
- [ ] nRF Connect app sees "UWB-Anchor-1"
- [ ] nRF Connect app sees "UWB-Anchor-2"
- [ ] nRF Connect app sees "UWB-Anchor-3"
- [ ] GATT NI service UUID visible in service discovery

## Phase 3: Anchor Firmware — UWB & NI Protocol

- [ ] DW3110 SPI communication verified (device ID read)
- [ ] NI library initialized, 38-byte config data generated
- [ ] GATT characteristic contains valid config data
- [ ] Shareable config write handler implemented
- [ ] All 3 boards flashed with respective configs
- [ ] Single anchor ranges with Qorvo iOS app
- [ ] All 3 anchors range simultaneously with Qorvo app

## Phase 4: iOS App — Project Setup & CoreBluetooth

- [ ] Xcode project created (SwiftUI, iOS 17.0+)
- [ ] Info.plist configured (NI + BLE usage descriptions)
- [ ] Nearby Interaction capability enabled
- [ ] Background Modes enabled (BLE + NI)
- [ ] `BluetoothManager` implemented (scan, connect, GATT)
- [ ] `Anchor` model defined
- [ ] `AnchorListView` shows discovered anchors
- [ ] `Constants.swift` with NI GATT UUIDs
- [ ] App builds and runs on iPhone 16 Pro Max
- [ ] BLE scan discovers all 3 anchors
- [ ] BLE connection + GATT discovery works
- [ ] Accessory Config Data read successfully

## Phase 5: iOS App — NI Sessions & Ranging

- [ ] `NearbyInteractionManager` implemented
- [ ] `NINearbyAccessoryConfiguration` created from config data
- [ ] Shareable config data sent to anchor via BLE GATT
- [ ] Distance updates received via `session(_:didUpdate:)`
- [ ] Session timeout/reconnection handled
- [ ] `PositioningViewModel` wired up
- [ ] Single anchor ranging works end-to-end
- [ ] 3 anchors range simultaneously

## Phase 6: iOS App — Trilateration & UI

- [ ] `TrilaterationEngine` implemented (least-squares)
- [ ] Trilateration verified with synthetic test data
- [ ] `PositionFilter` implemented (moving average)
- [ ] `FloorPlanView` renders anchors and position
- [ ] `AnchorListView` shows distances and status
- [ ] Real-time position tracking working
- [ ] Weighted trilateration variant implemented

## Phase 7: System Integration & Single-Anchor Validation

- [ ] End-to-end pipeline works with custom app + one anchor
- [ ] Distance accuracy validated at multiple distances
- [ ] `DataExportService` exports CSV
- [ ] CSV contains valid measurement data

## Phase 8: Multi-Anchor Positioning & Calibration

- [ ] 3 anchors deployed in test space
- [ ] Anchor positions measured and configured in app
- [ ] Simultaneous ranging to all 3 verified
- [ ] Antenna delay calibration performed
- [ ] Test grid measurements collected (12 points)
- [ ] Positioning error calculated
- [ ] GDOP analysis implemented

## Phase 9: Measurements & Thesis Data Collection

- [ ] Experiment 1: Distance accuracy (LOS) completed
- [ ] Experiment 2: Distance accuracy (NLOS) completed
- [ ] Experiment 3: 2D positioning accuracy completed
- [ ] Experiment 4: Update rate & latency completed
- [ ] Experiment 5: Anchor geometry effect completed
- [ ] Python analysis scripts written
- [ ] Thesis figures generated
- [ ] All data committed to `measurements/`

## Phase 10: Documentation & Thesis Writing

- [ ] `README.md` updated with full project docs
- [ ] `docs/` populated (architecture, placement, wiring)
- [ ] Thesis theory section drafted
- [ ] Thesis system design section drafted
- [ ] Thesis implementation section drafted
- [ ] Thesis results section drafted
- [ ] Thesis discussion section drafted

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-22 | Use Qorvo DW3_QM33 SDK (not nRF Connect SDK) | NI accessory protocol is built-in; implementing from scratch infeasible for thesis |
| 2026-02-22 | 2D positioning (not 3D) | 3 anchors is minimum for 3D; 2D is more robust and sufficient for thesis |
| 2026-02-22 | Direct iPhone-to-anchor ranging via NI | iPhone U2 chip supports direct UWB ranging with DW3110; no board-to-board needed |
| 2026-02-22 | SwiftUI (not UIKit) | Modern iOS framework; user has some Flutter experience so declarative UI is familiar |

## Known Issues

_None yet — project hasn't started implementation._

## Notes

- Phase 4 (iOS app setup) can begin in parallel with Phase 2/3 (firmware) once Phase 1 is complete
- Keep firmware changes minimal — the Qorvo SDK does most of the heavy lifting
- Test with Qorvo's own iOS app first to isolate firmware vs app issues
