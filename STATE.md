# Project State Tracker

> This file tracks the current implementation state of the UWB/BLE positioning system.
> Updated as work progresses through each phase.

---

## Current Phase: Phase 5 — iOS App — NI Sessions & Ranging

## Overall Progress

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Dev Environment Setup & Smoke Test | COMPLETE | |
| 2. Anchor Firmware — BLE & Identity | COMPLETE | |
| 3. Anchor Firmware — UWB & NI Protocol | COMPLETE | All SDK-provided; verified with modified firmware |
| 4. iOS App — Project Setup & CoreBluetooth | COMPLETE | BLE scan, connect, GATT, ACD all verified on device |
| 5. iOS App — NI Sessions & Ranging | NOT STARTED | |
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

- [x] Qorvo NI firmware source code studied and understood
- [x] `anchor_config.h` created with ANCHOR_ID defines
- [x] BLE advertising modified with unique device names
- [x] 3 build configurations created (cmake `-DANCHOR_ID=1/2/3`)
- [x] LED status indicators implemented
- [x] RTT debug logging added
- [x] Source files copied into `firmware/anchor/` in repo
- [x] nRF Connect app sees "UWB-Anchor-1"
- [x] nRF Connect app sees "UWB-Anchor-2"
- [x] nRF Connect app sees "UWB-Anchor-3"
- [x] GATT NI service UUID visible in service discovery

## Phase 3: Anchor Firmware — UWB & NI Protocol

> Items 1-4 are implemented by Qorvo SDK (libniq + ble_niq + QNIS/ANIS services). Verified working via successful ranging.

- [x] DW3110 SPI communication verified (device ID read)
- [x] NI library initialized, 38-byte config data generated
- [x] GATT characteristic contains valid config data
- [x] Shareable config write handler implemented
- [x] All 3 boards flashed with respective configs
- [x] Single anchor ranges with Qorvo iOS app
- [x] All 3 anchors range simultaneously with Qorvo app

## Phase 4: iOS App — Project Setup & CoreBluetooth

- [x] Xcode project created (SwiftUI, iOS 26.5)
- [x] Info.plist configured (NI + BLE usage descriptions)
- [x] Nearby Interaction capability enabled
- [x] Background Modes enabled (BLE + NI)
- [x] `BluetoothManager` implemented (scan, connect, GATT, NI messages)
- [x] `Anchor` model defined
- [x] `AnchorListView` shows discovered anchors
- [x] `Constants.swift` with QNIS GATT UUIDs (corrected from firmware source)
- [x] App builds successfully (xcodebuild, no code signing)
- [x] App runs on iPhone 16 Pro Max
- [x] BLE scan discovers all 3 anchors
- [x] BLE connection + GATT discovery works
- [x] Accessory Config Data read successfully

## Phase 5: iOS App — NI Sessions & Ranging

- [x] `NearbyInteractionManager` implemented
- [x] `NINearbyAccessoryConfiguration` created from config data
- [x] Shareable config data sent to anchor via BLE GATT
- [x] Distance updates received via `session(_:didUpdate:)`
- [x] Session timeout/reconnection handled
- [x] `PositioningViewModel` wired up
- [x] Single anchor ranging works end-to-end
- [x] 3 anchors range simultaneously

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
| 2026-05-15 | CMake build (not SEGGER ES) | Qorvo SDK uses CMake + ARM GCC, not .emProject files; custom `build_anchor.sh` calls cmake with `-DANCHOR_ID=N` |
| 2026-05-15 | CONFIG_LOG enabled | RTT logging via QLOG macros; changed `CONFIG_LOG OFF` → `ON` in QANI-FreeRTOS.cmake |
| 2026-05-15 | Phase 3 items 1-4 already in SDK | Qorvo QANI firmware includes complete NI protocol: SPI/DW3110 driver, libniq, GATT services (QNIS+ANIS), shareable config handler |
| 2026-05-15 | Corrected BLE UUIDs: QNIS not Apple NI spec | Firmware uses QNIS service (2E938FD0-6A61-11ED-...) not Apple standard (15171523-...) |

## Known Issues

- `nrfjprog` shows non-fatal J-Link error -256 (version mismatch between nrfjprog 10.24.2 and J-Link V9.42) — all operations still succeed
- VSCode IntelliSense shows `#include` errors for SDK headers — false positives, the CMake build resolves all paths correctly

## Notes

- Phase 4 (iOS app setup) can begin in parallel with Phase 2/3 (firmware) once Phase 1 is complete
- Keep firmware changes minimal — the Qorvo SDK does most of the heavy lifting
- Test with Qorvo's own iOS app first to isolate firmware vs app issues
