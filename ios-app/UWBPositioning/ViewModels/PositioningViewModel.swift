import SwiftUI
import Combine
import os

/// Coordinates BLE, NearbyInteraction, and trilateration for UWB positioning.
///
/// Owns `BluetoothManager`, `NearbyInteractionManager`, and position computation.
/// Wires the ACD callback to trigger NI sessions, routes shareable config back
/// through BLE, and runs trilateration at 10 Hz to compute the tag's 2D position.
class PositioningViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "PositioningVM")

    @Published var bluetoothManager = BluetoothManager()
    let niManager = NearbyInteractionManager()

    // MARK: - Positioning

    /// Smoothed 2D position of the tag (nil when < 3 distances available)
    @Published var computedPosition: CGPoint?

    /// Raw (unfiltered) position for debug display
    @Published var rawPosition: CGPoint?

    /// Whether to use weighted trilateration (closer anchors trusted more)
    @Published var useWeightedTrilateration: Bool = true

    private let positionFilter = PositionFilter(windowSize: 5)
    private var trilaterationTimer: Timer?
    private let trilaterationInterval: TimeInterval = 0.1 // 10 Hz

    /// Maximum age of a distance reading before it's considered stale
    private let maxDistanceAge: TimeInterval = 2.0

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupCallbacks()
        startTrilaterationUpdates()

        // Forward BluetoothManager's published changes so SwiftUI views update
        bluetoothManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    deinit {
        trilaterationTimer?.invalidate()
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

    // MARK: - Trilateration

    private func startTrilaterationUpdates() {
        trilaterationTimer = Timer.scheduledTimer(withTimeInterval: trilaterationInterval, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    private func stopTrilaterationUpdates() {
        trilaterationTimer?.invalidate()
        trilaterationTimer = nil
        positionFilter.reset()
        computedPosition = nil
        rawPosition = nil
    }

    private func updatePosition() {
        let now = Date()

        // Collect valid distances from ranging anchors with fresh data
        var distances: [TrilaterationEngine.DistanceMeasurement] = []
        for anchor in bluetoothManager.anchors.values {
            guard anchor.state == .ranging,
                  let distance = anchor.distance,
                  let lastUpdate = anchor.lastDistanceUpdate,
                  now.timeIntervalSince(lastUpdate) < maxDistanceAge else {
                continue
            }
            distances.append(.init(anchorId: anchor.anchorId, distance: distance))
        }

        // Build anchor positions from defaults
        let anchorPositions = AnchorDefaults.positions.map {
            TrilaterationEngine.AnchorPosition(anchorId: $0.anchorId, x: $0.x, y: $0.y)
        }

        // Compute position
        let raw: CGPoint?
        if useWeightedTrilateration {
            raw = TrilaterationEngine.computeWeightedPosition(anchors: anchorPositions, distances: distances)
        } else {
            raw = TrilaterationEngine.computePosition(anchors: anchorPositions, distances: distances)
        }

        rawPosition = raw

        if let raw {
            computedPosition = positionFilter.addPosition(raw)
        } else {
            computedPosition = nil
        }
    }

    // MARK: - Public API

    /// Disconnect an anchor and stop its NI session
    func disconnectAnchor(_ anchor: Anchor) {
        niManager.stopSession(for: anchor)
        bluetoothManager.disconnect(anchor)
    }

    /// Stop all NI sessions and trilateration
    func stopAllRanging() {
        niManager.stopAllSessions()
        stopTrilaterationUpdates()
    }
}
