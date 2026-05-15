import Foundation

/// Moving-average filter for smoothing 2D position estimates.
///
/// Maintains a sliding window of recent positions and returns the component-wise average.
class PositionFilter {
    private let windowSize: Int
    private var buffer: [CGPoint] = []

    init(windowSize: Int = 5) {
        self.windowSize = max(windowSize, 1)
    }

    /// Add a new position and return the smoothed (averaged) position.
    func addPosition(_ position: CGPoint) -> CGPoint {
        buffer.append(position)
        if buffer.count > windowSize {
            buffer.removeFirst(buffer.count - windowSize)
        }
        return average()
    }

    /// Current smoothed position, or nil if no data.
    var currentSmoothedPosition: CGPoint? {
        buffer.isEmpty ? nil : average()
    }

    /// Clear all buffered positions.
    func reset() {
        buffer.removeAll()
    }

    // MARK: - Private

    private func average() -> CGPoint {
        let count = CGFloat(buffer.count)
        let sumX = buffer.reduce(0.0) { $0 + $1.x }
        let sumY = buffer.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: sumX / count, y: sumY / count)
    }
}
