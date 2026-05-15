import Foundation
import Combine
import os

/// Per-anchor configuration: position in meters and distance calibration offset.
struct AnchorConfig: Codable, Identifiable {
    var id: Int { anchorId }
    let anchorId: Int
    var x: Float
    var y: Float
    /// Offset added to measured distance (meters). Positive = anchor reads too short.
    var distanceOffset: Float
}

/// Persists anchor positions and calibration offsets to UserDefaults.
///
/// Falls back to `AnchorDefaults.positions` when no saved configuration exists.
class AnchorConfigStore: ObservableObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "AnchorConfig")
    private static let userDefaultsKey = "anchorConfigs"

    @Published var configs: [AnchorConfig] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let saved = try? JSONDecoder().decode([AnchorConfig].self, from: data) {
            configs = saved
            logger.info("Loaded \(saved.count) anchor configs from UserDefaults")
        } else {
            configs = AnchorDefaults.positions.map {
                AnchorConfig(anchorId: $0.anchorId, x: $0.x, y: $0.y, distanceOffset: 0.0)
            }
            logger.info("No saved config — using defaults")
        }
    }

    func config(for anchorId: Int) -> AnchorConfig? {
        configs.first { $0.anchorId == anchorId }
    }

    func updatePosition(anchorId: Int, x: Float, y: Float) {
        guard let idx = configs.firstIndex(where: { $0.anchorId == anchorId }) else { return }
        configs[idx].x = x
        configs[idx].y = y
    }

    func updateOffset(anchorId: Int, offset: Float) {
        guard let idx = configs.firstIndex(where: { $0.anchorId == anchorId }) else { return }
        configs[idx].distanceOffset = offset
    }

    func resetToDefaults() {
        configs = AnchorDefaults.positions.map {
            AnchorConfig(anchorId: $0.anchorId, x: $0.x, y: $0.y, distanceOffset: 0.0)
        }
        logger.info("Anchor configs reset to defaults")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
