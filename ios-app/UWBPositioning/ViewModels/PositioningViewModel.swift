import SwiftUI
import Combine
import os

/// Coordinates BLE and NearbyInteraction services for UWB ranging.
///
/// Owns both `BluetoothManager` and `NearbyInteractionManager`,
/// wires the ACD callback to trigger NI sessions,
/// and routes shareable config back through BLE.
class PositioningViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "PositioningVM")

    @Published var bluetoothManager = BluetoothManager()
    let niManager = NearbyInteractionManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupCallbacks()

        // Forward BluetoothManager's published changes so SwiftUI views update
        bluetoothManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Callback Wiring

    private func setupCallbacks() {
        // When BLE receives ACD from an anchor, start an NI session
        bluetoothManager.onAccessoryConfigDataReceived = { [weak self] anchor in
            guard let self else { return }
            self.logger.info("ACD received for \(anchor.name) — starting NI session")
            self.niManager.startSession(for: anchor)
        }

        // When NI generates shareable config, send it to anchor via BLE (TIME CRITICAL)
        niManager.onShareableConfigGenerated = { [weak self] anchor, shareableData in
            guard let self else { return }
            self.logger.info("Sending shareable config to \(anchor.name) via BLE")
            self.bluetoothManager.sendConfigureAndStart(anchor, shareableData: shareableData)
        }

        // When NI session is invalidated, handle recovery
        niManager.onSessionInvalidated = { [weak self] anchor in
            guard let self else { return }
            self.logger.warning("NI session invalidated for \(anchor.name)")
            self.handleSessionInvalidation(anchor: anchor)
        }

        // When BLE disconnects, stop the NI session for that anchor
        bluetoothManager.onAnchorDisconnected = { [weak self] anchor in
            guard let self else { return }
            self.logger.info("BLE disconnected for \(anchor.name) — stopping NI session")
            self.niManager.stopSession(for: anchor)
        }
    }

    // MARK: - Recovery

    private func handleSessionInvalidation(anchor: Anchor) {
        // If anchor is still BLE-connected and has ACD, re-request to restart the flow
        if anchor.state == .ranging || anchor.state == .configReceived,
           anchor.accessoryConfigData != nil {
            logger.info("Attempting NI session recovery for \(anchor.name)")
            bluetoothManager.requestAccessoryConfigData(anchor)
        }
    }

    // MARK: - Public API

    /// Disconnect an anchor and stop its NI session
    func disconnectAnchor(_ anchor: Anchor) {
        niManager.stopSession(for: anchor)
        bluetoothManager.disconnect(anchor)
    }

    /// Stop all NI sessions
    func stopAllRanging() {
        niManager.stopAllSessions()
    }
}
