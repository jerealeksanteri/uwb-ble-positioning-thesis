import Foundation
import Combine
import simd
import os

/// Records UWB measurements and exports them as CSV.
///
/// Supports two modes:
/// - **Distance**: captures individual NI distance updates from a single anchor
/// - **Position**: captures computed 2D positions from trilateration (all anchors)
class DataExportService: ObservableObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "DataExport")

    enum RecordingMode: String, CaseIterable {
        case distance = "Distance"
        case position = "Position"
    }

    // MARK: - Recording State

    @Published var recordingMode: RecordingMode = .distance
    @Published var isRecording: Bool = false
    @Published var sampleCount: Int = 0
    @Published var targetSampleCount: Int = 100

    // Distance mode config
    @Published var recordingAnchorId: Int?
    @Published var trueDistance: Float = 1.0

    // Position mode config
    @Published var trueX: Float = 0.0
    @Published var trueY: Float = 0.0

    // MARK: - Distance Samples

    private(set) var samples: [DistanceSample] = []

    struct DistanceSample {
        let timestamp: Date
        let anchorId: Int
        let trueDistance: Float
        let measuredDistance: Float
        let dirX: Float?
        let dirY: Float?
        let dirZ: Float?
    }

    // MARK: - Position Samples

    private(set) var positionSamples: [PositionSample] = []
    @Published var positionSampleCount: Int = 0

    struct PositionSample {
        let timestamp: Date
        let trueX: Float
        let trueY: Float
        let computedX: Float
        let computedY: Float
        let filteredX: Float
        let filteredY: Float
        let hdop: Float?
        let d1: Float?
        let d2: Float?
        let d3: Float?
    }

    // MARK: - Distance Recording API

    func startRecording(anchorId: Int, trueDistance: Float, targetCount: Int = 100) {
        samples = []
        sampleCount = 0
        recordingAnchorId = anchorId
        self.trueDistance = trueDistance
        targetSampleCount = targetCount
        recordingMode = .distance
        isRecording = true
        logger.info("Started distance recording: anchor=\(anchorId), trueDistance=\(trueDistance)m, target=\(targetCount)")
    }

    func recordSample(anchorId: Int, measuredDistance: Float, direction: simd_float3?) {
        guard isRecording, recordingMode == .distance, anchorId == recordingAnchorId else { return }

        let sample = DistanceSample(
            timestamp: Date(),
            anchorId: anchorId,
            trueDistance: trueDistance,
            measuredDistance: measuredDistance,
            dirX: direction?.x,
            dirY: direction?.y,
            dirZ: direction?.z
        )
        samples.append(sample)
        sampleCount = samples.count

        if sampleCount >= targetSampleCount {
            stopRecording()
        }
    }

    // MARK: - Position Recording API

    func startPositionRecording(trueX: Float, trueY: Float, targetCount: Int = 100) {
        positionSamples = []
        positionSampleCount = 0
        sampleCount = 0
        self.trueX = trueX
        self.trueY = trueY
        targetSampleCount = targetCount
        recordingMode = .position
        isRecording = true
        logger.info("Started position recording: true=(\(trueX), \(trueY)), target=\(targetCount)")
    }

    func recordPositionSample(computed: CGPoint, filtered: CGPoint, hdop: Float?, distances: [Int: Float]) {
        guard isRecording, recordingMode == .position else { return }

        let sample = PositionSample(
            timestamp: Date(),
            trueX: trueX,
            trueY: trueY,
            computedX: Float(computed.x),
            computedY: Float(computed.y),
            filteredX: Float(filtered.x),
            filteredY: Float(filtered.y),
            hdop: hdop,
            d1: distances[1],
            d2: distances[2],
            d3: distances[3]
        )
        positionSamples.append(sample)
        positionSampleCount = positionSamples.count
        sampleCount = positionSampleCount

        if positionSampleCount >= targetSampleCount {
            stopRecording()
        }
    }

    // MARK: - Common API

    func stopRecording() {
        isRecording = false
        logger.info("Stopped recording: \(self.sampleCount) samples collected")
    }

    func discardRecording() {
        isRecording = false
        samples = []
        sampleCount = 0
        positionSamples = []
        positionSampleCount = 0
        logger.info("Recording discarded")
    }

    // MARK: - Distance CSV Export

    func exportCSV() -> URL? {
        guard !samples.isEmpty else {
            logger.warning("No distance samples to export")
            return nil
        }

        let header = "timestamp,anchor_id,true_distance,measured_distance,dir_x,dir_y,dir_z\n"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var csv = header
        for sample in samples {
            let ts = isoFormatter.string(from: sample.timestamp)
            let dirX = sample.dirX.map { String(format: "%.6f", $0) } ?? ""
            let dirY = sample.dirY.map { String(format: "%.6f", $0) } ?? ""
            let dirZ = sample.dirZ.map { String(format: "%.6f", $0) } ?? ""
            csv += "\(ts),\(sample.anchorId),\(String(format: "%.3f", sample.trueDistance)),\(String(format: "%.4f", sample.measuredDistance)),\(dirX),\(dirY),\(dirZ)\n"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = dateFormatter.string(from: Date())
        let anchorStr = recordingAnchorId.map { "A\($0)" } ?? "unknown"
        let distStr = String(format: "%.1f", trueDistance).replacingOccurrences(of: ".", with: "p")
        let filename = "uwb_distance_\(anchorStr)_\(distStr)m_\(dateStr).csv"

        return writeCSV(csv, filename: filename)
    }

    // MARK: - Position CSV Export

    func exportPositionCSV() -> URL? {
        guard !positionSamples.isEmpty else {
            logger.warning("No position samples to export")
            return nil
        }

        let header = "timestamp,true_x,true_y,computed_x,computed_y,filtered_x,filtered_y,hdop,d1,d2,d3\n"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var csv = header
        for s in positionSamples {
            let ts = isoFormatter.string(from: s.timestamp)
            let hdop = s.hdop.map { String(format: "%.3f", $0) } ?? ""
            let d1 = s.d1.map { String(format: "%.4f", $0) } ?? ""
            let d2 = s.d2.map { String(format: "%.4f", $0) } ?? ""
            let d3 = s.d3.map { String(format: "%.4f", $0) } ?? ""
            csv += "\(ts),\(String(format: "%.3f", s.trueX)),\(String(format: "%.3f", s.trueY)),\(String(format: "%.4f", s.computedX)),\(String(format: "%.4f", s.computedY)),\(String(format: "%.4f", s.filteredX)),\(String(format: "%.4f", s.filteredY)),\(hdop),\(d1),\(d2),\(d3)\n"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = dateFormatter.string(from: Date())
        let xStr = String(format: "%.1f", trueX).replacingOccurrences(of: ".", with: "p")
        let yStr = String(format: "%.1f", trueY).replacingOccurrences(of: ".", with: "p")
        let filename = "uwb_position_\(xStr)x\(yStr)_\(dateStr).csv"

        return writeCSV(csv, filename: filename)
    }

    private func writeCSV(_ content: String, filename: String) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            logger.info("Exported CSV: \(filename)")
            return tempURL
        } catch {
            logger.error("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Distance Statistics

    var meanError: Float? {
        guard !samples.isEmpty else { return nil }
        let errors = samples.map { $0.measuredDistance - $0.trueDistance }
        return errors.reduce(0, +) / Float(errors.count)
    }

    var stdDev: Float? {
        guard samples.count > 1, let mean = meanError else { return nil }
        let squaredDiffs = samples.map { ($0.measuredDistance - $0.trueDistance - mean) }
            .map { $0 * $0 }
        let variance = squaredDiffs.reduce(0, +) / Float(squaredDiffs.count - 1)
        return sqrt(variance)
    }

    var meanDistance: Float? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.measuredDistance).reduce(0, +) / Float(samples.count)
    }

    var minDistance: Float? {
        samples.map(\.measuredDistance).min()
    }

    var maxDistance: Float? {
        samples.map(\.measuredDistance).max()
    }

    // MARK: - Position Statistics

    /// Position errors for each sample (Euclidean distance from true to computed position)
    private var positionErrors: [Float] {
        positionSamples.map { s in
            let dx = s.computedX - s.trueX
            let dy = s.computedY - s.trueY
            return sqrt(dx * dx + dy * dy)
        }
    }

    var meanPositionError: Float? {
        guard !positionErrors.isEmpty else { return nil }
        return positionErrors.reduce(0, +) / Float(positionErrors.count)
    }

    /// CEP50: 50th percentile position error (meters)
    var cep50: Float? {
        let sorted = positionErrors.sorted()
        guard !sorted.isEmpty else { return nil }
        let idx = Int(Float(sorted.count) * 0.5)
        return sorted[min(idx, sorted.count - 1)]
    }

    /// CEP95: 95th percentile position error (meters)
    var cep95: Float? {
        let sorted = positionErrors.sorted()
        guard !sorted.isEmpty else { return nil }
        let idx = Int(Float(sorted.count) * 0.95)
        return sorted[min(idx, sorted.count - 1)]
    }

    var meanHDOP: Float? {
        let hdops = positionSamples.compactMap(\.hdop)
        guard !hdops.isEmpty else { return nil }
        return hdops.reduce(0, +) / Float(hdops.count)
    }
}
