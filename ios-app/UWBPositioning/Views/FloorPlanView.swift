import SwiftUI

struct FloorPlanView: View {
    @ObservedObject var viewModel: PositioningViewModel

    private var bluetoothManager: BluetoothManager { viewModel.bluetoothManager }
    private var anchorConfigs: [AnchorConfig] { viewModel.anchorConfigStore.configs }

    var body: some View {
        GeometryReader { geometry in
            let transform = CoordinateTransform(
                anchorPositions: anchorConfigs.map { (x: $0.x, y: $0.y) },
                canvasSize: geometry.size
            )

            Canvas { context, size in
                drawGrid(context: &context, transform: transform)
                drawAnchors(context: &context, transform: transform)
                drawTagPosition(context: &context, transform: transform)
            }
            .overlay(alignment: .bottom) {
                positionStatusOverlay
                    .padding(.bottom, 16)
            }
        }
        .padding(8)
    }

    // MARK: - Status Overlay

    @ViewBuilder
    private var positionStatusOverlay: some View {
        if let pos = viewModel.computedPosition {
            HStack(spacing: 8) {
                Text(String(format: "(%.2f, %.2f) m", pos.x, pos.y))
                    .fontWeight(.medium)
                if let hdop = viewModel.currentHDOP {
                    Text(String(format: "HDOP %.1f", hdop))
                        .foregroundStyle(hdop < 2 ? .green : hdop < 5 ? .orange : .red)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        } else {
            let rangingCount = bluetoothManager.anchors.values.filter { $0.state == .ranging }.count
            Text("Waiting for distances (\(rangingCount)/3 anchors ranging)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }

    // MARK: - Drawing

    private func drawGrid(context: inout GraphicsContext, transform: CoordinateTransform) {
        let gridColor = Color.gray.opacity(0.2)
        let labelColor = Color.gray

        let minX = Int(floor(transform.worldMinX))
        let maxX = Int(ceil(transform.worldMaxX))
        let minY = Int(floor(transform.worldMinY))
        let maxY = Int(ceil(transform.worldMaxY))

        // Vertical lines
        for x in minX...maxX {
            let top = transform.worldToScreen(CGPoint(x: CGFloat(x), y: transform.worldMaxY))
            let bottom = transform.worldToScreen(CGPoint(x: CGFloat(x), y: transform.worldMinY))
            var path = Path()
            path.move(to: top)
            path.addLine(to: bottom)
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            // Label at bottom
            let labelPos = CGPoint(x: bottom.x, y: bottom.y + 12)
            context.draw(
                Text("\(x)m").font(.system(size: 10)).foregroundColor(labelColor),
                at: labelPos
            )
        }

        // Horizontal lines
        for y in minY...maxY {
            let left = transform.worldToScreen(CGPoint(x: transform.worldMinX, y: CGFloat(y)))
            let right = transform.worldToScreen(CGPoint(x: transform.worldMaxX, y: CGFloat(y)))
            var path = Path()
            path.move(to: left)
            path.addLine(to: right)
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            // Label at left
            let labelPos = CGPoint(x: left.x - 16, y: left.y)
            context.draw(
                Text("\(y)m").font(.system(size: 10)).foregroundColor(labelColor),
                at: labelPos
            )
        }
    }

    private func drawAnchors(context: inout GraphicsContext, transform: CoordinateTransform) {
        for config in anchorConfigs {
            let screenPos = transform.worldToScreen(
                CGPoint(x: CGFloat(config.x), y: CGFloat(config.y))
            )

            // Find the matching anchor for state and distance info
            let anchor = bluetoothManager.anchors.values.first { $0.anchorId == config.anchorId }
            let isRanging = anchor?.state == .ranging
            let color: Color = isRanging ? .purple : .gray

            // Draw triangle
            let side: CGFloat = 24
            let height = side * sqrt(3) / 2
            let triangle = Path { p in
                p.move(to: CGPoint(x: screenPos.x, y: screenPos.y - height * 2 / 3))
                p.addLine(to: CGPoint(x: screenPos.x - side / 2, y: screenPos.y + height / 3))
                p.addLine(to: CGPoint(x: screenPos.x + side / 2, y: screenPos.y + height / 3))
                p.closeSubpath()
            }
            context.fill(triangle, with: .color(color.opacity(0.3)))
            context.stroke(triangle, with: .color(color), lineWidth: 2)

            // Anchor label
            context.draw(
                Text("A\(config.anchorId)").font(.caption).fontWeight(.bold).foregroundColor(color),
                at: CGPoint(x: screenPos.x, y: screenPos.y + height / 3 + 16)
            )

            // Distance label when ranging
            if let distance = anchor?.distance, isRanging {
                context.draw(
                    Text(String(format: "%.2f m", distance))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.purple),
                    at: CGPoint(x: screenPos.x, y: screenPos.y - height * 2 / 3 - 12)
                )
            }
        }
    }

    private func drawTagPosition(context: inout GraphicsContext, transform: CoordinateTransform) {
        guard let position = viewModel.computedPosition else { return }

        let screenPos = transform.worldToScreen(position)

        // Halo
        let haloRect = CGRect(x: screenPos.x - 16, y: screenPos.y - 16, width: 32, height: 32)
        context.fill(Path(ellipseIn: haloRect), with: .color(.blue.opacity(0.15)))

        // Dot
        let dotRect = CGRect(x: screenPos.x - 8, y: screenPos.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: dotRect), with: .color(.blue))
    }
}

// MARK: - Coordinate Transform

private struct CoordinateTransform {
    let worldMinX: CGFloat
    let worldMinY: CGFloat
    let worldMaxX: CGFloat
    let worldMaxY: CGFloat
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let canvasSize: CGSize

    init(anchorPositions: [(x: Float, y: Float)], canvasSize: CGSize, paddingMeters: CGFloat = 1.5) {
        guard !anchorPositions.isEmpty else {
            self.worldMinX = -1; self.worldMinY = -1
            self.worldMaxX = 1; self.worldMaxY = 1
            self.scale = 1; self.offsetX = 0; self.offsetY = 0
            self.canvasSize = canvasSize
            return
        }

        let xs = anchorPositions.map { CGFloat($0.x) }
        let ys = anchorPositions.map { CGFloat($0.y) }

        worldMinX = (xs.min() ?? 0) - paddingMeters
        worldMaxX = (xs.max() ?? 0) + paddingMeters
        worldMinY = (ys.min() ?? 0) - paddingMeters
        worldMaxY = (ys.max() ?? 0) + paddingMeters

        let worldWidth = worldMaxX - worldMinX
        let worldHeight = worldMaxY - worldMinY

        // Leave margins for labels
        let drawableWidth = canvasSize.width - 40
        let drawableHeight = canvasSize.height - 40

        scale = min(drawableWidth / worldWidth, drawableHeight / worldHeight)

        // Center the drawing
        offsetX = (canvasSize.width - worldWidth * scale) / 2
        offsetY = (canvasSize.height - worldHeight * scale) / 2

        self.canvasSize = canvasSize
    }

    /// Convert world coordinates (meters) to screen coordinates (points).
    /// Y-axis is flipped: world Y increases upward, screen Y increases downward.
    func worldToScreen(_ worldPoint: CGPoint) -> CGPoint {
        let screenX = (worldPoint.x - worldMinX) * scale + offsetX
        let screenY = (worldMaxY - worldPoint.y) * scale + offsetY
        return CGPoint(x: screenX, y: screenY)
    }
}
