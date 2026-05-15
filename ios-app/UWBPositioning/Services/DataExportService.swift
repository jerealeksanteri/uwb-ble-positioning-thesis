import Foundation
import Combine
import simd
import os

/// Records individual UWB distance measurements and exports them as CSV.
///
/// Each sample captures a single NI distance update (not timer-sampled),
/// enabling accurate characterization of ranging performance.
class DataExportService: ObservableObject {
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "DataExport")

    // MARK: - Recording State

    @Published var isRecording: Bool = false
    @Published var sampleCount: Int = 0
    @Published var targetSampleCount: Int = 100
    @Published var recordingAnchorId: Int?
    @Published var trueDistance: Float = 1.0

    // MARK: - Recorded Data

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

    // MARK: - Recording API

    func startRecording(anchorId: Int, trueDistance: Float, targetCount: Int = 100) {
        samples = []
        sampleCount = 0
        recordingAnchorId = anchorId
        self.trueDistance = trueDistance
        targetSampleCount = targetCount
        isRecording = true
        logger.info("Started recording: anchor=\(anchorId), trueDistance=\(trueDistance)m, target=\(targetCount)")
    }

    func recordSample(anchorId: Int, measuredDistance: Float, direction: simd_float3?) {
        guard isRecording, anchorId == recordingAnchorId else { return }

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

    func stopRecording() {
        isRecording = false
        logger.info("Stopped recording: \(self.sampleCount) samples collected")
    }

    func discardRecording() {
        isRecording = false
        samples = []
        sampleCount = 0
        logger.info("Recording discarded")
    }

    // MARK: - CSV Export

    func exportCSV() -> URL? {
        guard !samples.isEmpty else {
            logger.warning("No samples to export")
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

        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Cannot access Documents directory")
            return nil
        }

        let fileURL = documentsDir.appendingPathComponent(filename)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Exported CSV: \(filename) (\(self.samples.count) samples)")
            return fileURL
        } catch {
            logger.error("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Statistics

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
}
