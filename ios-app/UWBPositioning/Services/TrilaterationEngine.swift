import Foundation
import simd
import os

/// Stateless 2D trilateration engine using linear least-squares.
///
/// Given 3+ anchor positions and measured distances, computes the tag's (x, y) position.
/// Algorithm: subtract first circle equation from others to linearize → solve `Ax = b`.
struct TrilaterationEngine {
    private static let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "Trilateration")

    struct AnchorPosition {
        let anchorId: Int
        let x: Float
        let y: Float
    }

    struct DistanceMeasurement {
        let anchorId: Int
        let distance: Float
    }

    /// Compute 2D position using unweighted linear least-squares.
    /// Returns `nil` if fewer than 3 matched anchor-distance pairs, singular matrix, or non-finite result.
    static func computePosition(anchors: [AnchorPosition], distances: [DistanceMeasurement]) -> CGPoint? {
        guard let (matched, dists) = matchAnchorsAndDistances(anchors: anchors, distances: distances) else {
            return nil
        }
        return solve(anchors: matched, distances: dists, weighted: false)
    }

    /// Compute 2D position with distance-inverse-squared weighting.
    /// Closer anchors contribute more to the solution.
    static func computeWeightedPosition(anchors: [AnchorPosition], distances: [DistanceMeasurement]) -> CGPoint? {
        guard let (matched, dists) = matchAnchorsAndDistances(anchors: anchors, distances: distances) else {
            return nil
        }
        return solve(anchors: matched, distances: dists, weighted: true)
    }

    /// Compute HDOP (Horizontal Dilution of Precision) for the current geometry.
    ///
    /// Lower values indicate better anchor geometry. Typical: 1–2 (good), 2–5 (moderate), >5 (poor).
    /// Returns `nil` if fewer than 3 matched anchors or singular geometry.
    static func computeHDOP(
        anchors: [AnchorPosition],
        distances: [DistanceMeasurement],
        tagPosition: CGPoint
    ) -> Float? {
        guard let (matched, dists) = matchAnchorsAndDistances(anchors: anchors, distances: distances) else {
            return nil
        }

        let tx = Float(tagPosition.x)
        let ty = Float(tagPosition.y)

        // Build H^T H directly (2×2): H rows are unit direction from tag to each anchor
        var h00: Float = 0, h01: Float = 0, h11: Float = 0
        for i in 0..<matched.count {
            let di = max(dists[i], 0.01)
            let hx = (matched[i].x - tx) / di
            let hy = (matched[i].y - ty) / di
            h00 += hx * hx
            h01 += hx * hy
            h11 += hy * hy
        }

        let det = h00 * h11 - h01 * h01
        guard abs(det) > 1e-6 else { return nil }

        // Q = (H^T H)^-1, HDOP = sqrt(trace(Q))
        let q00 = h11 / det
        let q11 = h00 / det
        let hdop = sqrt(q00 + q11)
        return hdop.isFinite ? hdop : nil
    }

    // MARK: - Private

    /// Match anchors to distances by anchorId, returning paired arrays. Returns nil if < 3 matches.
    private static func matchAnchorsAndDistances(
        anchors: [AnchorPosition],
        distances: [DistanceMeasurement]
    ) -> (anchors: [AnchorPosition], distances: [Float])? {
        let distMap = Dictionary(distances.map { ($0.anchorId, $0.distance) }, uniquingKeysWith: { _, last in last })

        var matchedAnchors: [AnchorPosition] = []
        var matchedDistances: [Float] = []

        for anchor in anchors {
            if let d = distMap[anchor.anchorId] {
                matchedAnchors.append(anchor)
                matchedDistances.append(d)
            }
        }

        guard matchedAnchors.count >= 3 else {
            logger.debug("Trilateration needs 3+ distances, have \(matchedAnchors.count)")
            return nil
        }

        return (matchedAnchors, matchedDistances)
    }

    /// Solve the linearized system. With exactly 3 anchors this is a direct 2×2 solve.
    /// With N > 3 anchors, uses normal equations: x = (AᵀA)⁻¹Aᵀb.
    private static func solve(anchors: [AnchorPosition], distances: [Float], weighted: Bool) -> CGPoint? {
        let n = anchors.count
        // Reference anchor (index 0)
        let x1 = anchors[0].x
        let y1 = anchors[0].y
        let d1 = distances[0]
        let d1sq = d1 * d1
        let x1sq = x1 * x1
        let y1sq = y1 * y1

        // Build rows: one per anchor beyond the first
        var rows: [(a1: Float, a2: Float, b: Float, w: Float)] = []
        for i in 1..<n {
            let xi = anchors[i].x
            let yi = anchors[i].y
            let di = distances[i]

            let a1 = 2.0 * (xi - x1)
            let a2 = 2.0 * (yi - y1)
            let bi = d1sq - di * di - x1sq + xi * xi - y1sq + yi * yi

            let w: Float = weighted ? 1.0 / max(di, 0.1) / max(di, 0.1) : 1.0
            rows.append((a1, a2, bi, w))
        }

        if n == 3 {
            // Direct 2×2 solve
            let r0 = rows[0]
            let r1 = rows[1]

            let A = simd_float2x2(
                simd_float2(r0.a1 * r0.w, r1.a1 * r1.w),
                simd_float2(r0.a2 * r0.w, r1.a2 * r1.w)
            )
            let b = simd_float2(r0.b * r0.w, r1.b * r1.w)

            let det = A.determinant
            guard abs(det) > 1e-6 else {
                logger.warning("Singular matrix (det=\(det)) — anchors may be collinear")
                return nil
            }

            let result = A.inverse * b
            guard result.x.isFinite && result.y.isFinite else {
                logger.warning("Non-finite trilateration result")
                return nil
            }

            return CGPoint(x: CGFloat(result.x), y: CGFloat(result.y))
        } else {
            // Overdetermined: normal equations (AᵀWA)x = AᵀWb
            // Build AᵀWA (2×2) and AᵀWb (2×1)
            var ata00: Float = 0, ata01: Float = 0, ata11: Float = 0
            var atb0: Float = 0, atb1: Float = 0

            for row in rows {
                let wa1 = row.a1 * row.w
                let wa2 = row.a2 * row.w
                let wb = row.b * row.w

                ata00 += wa1 * row.a1
                ata01 += wa1 * row.a2
                ata11 += wa2 * row.a2
                atb0 += wa1 * row.b
                atb1 += wa2 * row.b
            }

            let ATA = simd_float2x2(
                simd_float2(ata00, ata01),
                simd_float2(ata01, ata11)
            )
            let ATb = simd_float2(atb0, atb1)

            let det = ATA.determinant
            guard abs(det) > 1e-6 else {
                logger.warning("Singular normal equation matrix (det=\(det))")
                return nil
            }

            let result = ATA.inverse * ATb
            guard result.x.isFinite && result.y.isFinite else {
                logger.warning("Non-finite trilateration result")
                return nil
            }

            return CGPoint(x: CGFloat(result.x), y: CGFloat(result.y))
        }
    }
}
