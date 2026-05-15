import NearbyInteraction
import os

/// Manages NearbyInteraction sessions for UWB ranging with anchor devices.
///
/// One NISession is created per anchor. Lifecycle:
/// 1. `startSession(for:)` when ACD received from anchor
/// 2. NISession generates shareable config → sent to anchor via `onShareableConfigGenerated`
/// 3. Anchor starts UWB → distance updates via `session(_:didUpdate:)`
/// 4. `stopSession(for:)` or `stopAllSessions()` to clean up
class NearbyInteractionManager: NSObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "NearbyInteraction")

    /// Active NI sessions keyed by anchor UUID (CBPeripheral.identifier)
    private var sessions: [UUID: NISession] = [:]

    /// Cached accessory configurations for session recovery
    private var configurations: [UUID: NINearbyAccessoryConfiguration] = [:]

    /// Reference to anchors for updating distance/direction
    private var anchors: [UUID: Anchor] = [:]

    // MARK: - Callbacks

    /// Called when shareable configuration data is generated and must be sent to anchor via BLE.
    /// CRITICAL: Must be handled within ~2 seconds or the session times out.
    var onShareableConfigGenerated: ((Anchor, Data) -> Void)?

    /// Called when a session is invalidated so the coordinator can attempt recovery.
    var onSessionInvalidated: ((Anchor) -> Void)?

    // MARK: - Public API

    /// Start an NI session for the given anchor using its accessory config data.
    func startSession(for anchor: Anchor) {
        guard let acdPayload = anchor.accessoryConfigData else {
            logger.error("Cannot start NI session for \(anchor.name): no ACD")
            return
        }

        // Invalidate any existing session for this anchor
        if let existingSession = sessions[anchor.id] {
            logger.info("Invalidating existing NI session for \(anchor.name)")
            existingSession.invalidate()
            sessions.removeValue(forKey: anchor.id)
        }

        // Create NINearbyAccessoryConfiguration from raw ACD payload
        let configuration: NINearbyAccessoryConfiguration
        do {
            configuration = try NINearbyAccessoryConfiguration(data: acdPayload)
        } catch {
            logger.error("Failed to create NI configuration for \(anchor.name): \(error.localizedDescription)")
            return
        }

        // Cache for session recovery
        configurations[anchor.id] = configuration
        anchors[anchor.id] = anchor

        // Create and run the session
        let session = NISession()
        session.delegate = self
        session.delegateQueue = .main
        sessions[anchor.id] = session

        logger.info("Running NI session for \(anchor.name)")
        session.run(configuration)
    }

    /// Stop the NI session for a specific anchor.
    func stopSession(for anchor: Anchor) {
        guard let session = sessions[anchor.id] else { return }
        logger.info("Stopping NI session for \(anchor.name)")
        session.invalidate()
        sessions.removeValue(forKey: anchor.id)
        configurations.removeValue(forKey: anchor.id)
        anchors.removeValue(forKey: anchor.id)
        anchor.clearRangingData()
    }

    /// Stop all active NI sessions.
    func stopAllSessions() {
        logger.info("Stopping all NI sessions (\(self.sessions.count) active)")
        for (anchorId, session) in sessions {
            session.invalidate()
            anchors[anchorId]?.clearRangingData()
        }
        sessions.removeAll()
        configurations.removeAll()
        anchors.removeAll()
    }

    /// Number of active sessions
    var activeSessionCount: Int {
        sessions.count
    }

    // MARK: - Private Helpers

    /// Find the anchor UUID associated with a given NISession
    private func anchorId(for session: NISession) -> UUID? {
        sessions.first(where: { $0.value === session })?.key
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionManager: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            logger.error("Received shareable config for unknown session")
            return
        }

        logger.info("Shareable config generated for \(anchor.name) (\(shareableConfigurationData.count) bytes)")
        onShareableConfigGenerated?(anchor, shareableConfigurationData)
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            return
        }

        guard let object = nearbyObjects.first else { return }

        if let distance = object.distance {
            anchor.distance = distance
            anchor.lastDistanceUpdate = Date()
        }

        if object.direction != nil {
            anchor.direction = object.direction
        }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            return
        }

        logger.info("NI object removed for \(anchor.name), reason: \(String(describing: reason))")

        switch reason {
        case .peerEnded:
            anchor.clearRangingData()
        case .timeout:
            logger.warning("NI session timed out for \(anchor.name) — attempting recovery")
            if let config = configurations[id] {
                session.run(config)
            }
        @unknown default:
            anchor.clearRangingData()
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            return
        }
        logger.info("NI session suspended for \(anchor.name)")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            return
        }
        logger.info("NI session suspension ended for \(anchor.name) — re-running")
        if let config = configurations[id] {
            session.run(config)
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        guard let id = anchorId(for: session),
              let anchor = anchors[id] else {
            return
        }

        logger.error("NI session invalidated for \(anchor.name): \(error.localizedDescription)")
        sessions.removeValue(forKey: id)
        anchor.clearRangingData()
        onSessionInvalidated?(anchor)
    }
}
