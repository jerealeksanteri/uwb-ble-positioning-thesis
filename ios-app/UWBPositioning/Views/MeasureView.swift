import SwiftUI

struct MeasureView: View {
    @ObservedObject var viewModel: PositioningViewModel

    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private var dataExport: DataExportService { viewModel.dataExportService }
    private var bluetoothManager: BluetoothManager { viewModel.bluetoothManager }

    private var rangingAnchors: [Anchor] {
        bluetoothManager.sortedAnchors.filter { $0.state == .ranging }
    }

    var body: some View {
        Form {
            modePicker

            if dataExport.recordingMode == .distance {
                distanceConfigSection
                distanceRecordingSection
                if dataExport.sampleCount > 0 { distanceStatisticsSection }
                if !dataExport.samples.isEmpty && !dataExport.isRecording { distanceExportSection }
            } else {
                positionConfigSection
                positionRecordingSection
                if dataExport.positionSampleCount > 0 { positionStatisticsSection }
                if !dataExport.positionSamples.isEmpty && !dataExport.isRecording { positionExportSection }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Mode Picker

    @ViewBuilder
    private var modePicker: some View {
        Picker("Mode", selection: $viewModel.dataExportService.recordingMode) {
            ForEach(DataExportService.RecordingMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(dataExport.isRecording)
        .listRowBackground(Color.clear)
    }

    // MARK: - Distance Mode

    @ViewBuilder
    private var distanceConfigSection: some View {
        Section("Configuration") {
            Picker("Anchor", selection: $viewModel.dataExportService.recordingAnchorId) {
                Text("Select...").tag(nil as Int?)
                ForEach(rangingAnchors) { anchor in
                    Text(anchor.name).tag(anchor.anchorId as Int?)
                }
            }
            .disabled(dataExport.isRecording)

            HStack {
                Text("True Distance")
                Spacer()
                TextField("meters", value: $viewModel.dataExportService.trueDistance, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("m")
                    .foregroundStyle(.secondary)
            }
            .disabled(dataExport.isRecording)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([0.5, 1.0, 2.0, 3.0, 5.0, 7.0, 10.0], id: \.self) { dist in
                        Button(String(format: "%.1f", dist)) {
                            dataExport.trueDistance = Float(dist)
                        }
                        .buttonStyle(.bordered)
                        .tint(dataExport.trueDistance == Float(dist) ? .blue : .gray)
                        .disabled(dataExport.isRecording)
                    }
                }
            }

            Stepper("Samples: \(dataExport.targetSampleCount)",
                    value: $viewModel.dataExportService.targetSampleCount,
                    in: 10...500, step: 10)
                .disabled(dataExport.isRecording)
        }
    }

    @ViewBuilder
    private var distanceRecordingSection: some View {
        Section("Recording") {
            sampleCountView

            if dataExport.isRecording,
               let anchorId = dataExport.recordingAnchorId,
               let anchor = bluetoothManager.anchors.values.first(where: { $0.anchorId == anchorId }) {
                HStack {
                    Label(anchor.distance.map { String(format: "%.3f m", $0) } ?? "---",
                          systemImage: "ruler")
                        .font(.title3)
                        .monospacedDigit()
                    Spacer()
                    Text("live")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(dataExport.isRecording ? "Stop" : "Start Recording") {
                    if dataExport.isRecording {
                        dataExport.stopRecording()
                    } else {
                        guard let anchorId = dataExport.recordingAnchorId else { return }
                        dataExport.startRecording(
                            anchorId: anchorId,
                            trueDistance: dataExport.trueDistance,
                            targetCount: dataExport.targetSampleCount
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(dataExport.isRecording ? .red : .green)
                .disabled(!dataExport.isRecording && dataExport.recordingAnchorId == nil)

                discardButton
            }
        }
    }

    @ViewBuilder
    private var distanceStatisticsSection: some View {
        Section("Statistics") {
            if let mean = dataExport.meanDistance {
                StatRow(label: "Mean distance", value: String(format: "%.4f m", mean))
            }
            if let meanErr = dataExport.meanError {
                StatRow(label: "Mean error", value: String(format: "%+.4f m", meanErr))
            }
            if let std = dataExport.stdDev {
                StatRow(label: "Std deviation", value: String(format: "%.4f m", std))
            }
            if let minD = dataExport.minDistance, let maxD = dataExport.maxDistance {
                StatRow(label: "Range", value: String(format: "%.4f ... %.4f m", minD, maxD))
            }
        }
    }

    @ViewBuilder
    private var distanceExportSection: some View {
        Section("Export") {
            Button {
                if let url = dataExport.exportCSV() {
                    shareURL = url
                    showShareSheet = true
                }
            } label: {
                Label("Export CSV & Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Position Mode

    @ViewBuilder
    private var positionConfigSection: some View {
        Section("True Position (meters)") {
            HStack {
                Text("X")
                    .frame(width: 20)
                TextField("X", value: $viewModel.dataExportService.trueX, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Text("Y")
                    .frame(width: 20)
                TextField("Y", value: $viewModel.dataExportService.trueY, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .disabled(dataExport.isRecording)

            Stepper("Samples: \(dataExport.targetSampleCount)",
                    value: $viewModel.dataExportService.targetSampleCount,
                    in: 10...500, step: 10)
                .disabled(dataExport.isRecording)

            if rangingAnchors.count < 3 {
                Label("Need 3 ranging anchors (\(rangingAnchors.count)/3)",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var positionRecordingSection: some View {
        Section("Recording") {
            sampleCountView

            if dataExport.isRecording || dataExport.positionSampleCount > 0 {
                if let pos = viewModel.computedPosition {
                    HStack {
                        Label(String(format: "(%.3f, %.3f)", pos.x, pos.y),
                              systemImage: "location")
                            .font(.title3)
                            .monospacedDigit()
                        Spacer()
                        if let hdop = viewModel.currentHDOP {
                            Text(String(format: "HDOP %.1f", hdop))
                                .font(.caption)
                                .foregroundStyle(hdop < 2 ? .green : hdop < 5 ? .orange : .red)
                        }
                    }
                }
            }

            HStack {
                Button(dataExport.isRecording ? "Stop" : "Start Recording") {
                    if dataExport.isRecording {
                        dataExport.stopRecording()
                    } else {
                        dataExport.startPositionRecording(
                            trueX: dataExport.trueX,
                            trueY: dataExport.trueY,
                            targetCount: dataExport.targetSampleCount
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(dataExport.isRecording ? .red : .green)
                .disabled(!dataExport.isRecording && rangingAnchors.count < 3)

                discardButton
            }
        }
    }

    @ViewBuilder
    private var positionStatisticsSection: some View {
        Section("Statistics") {
            if let err = dataExport.meanPositionError {
                StatRow(label: "Mean position error", value: String(format: "%.4f m", err))
            }
            if let c50 = dataExport.cep50 {
                StatRow(label: "CEP50", value: String(format: "%.4f m", c50))
            }
            if let c95 = dataExport.cep95 {
                StatRow(label: "CEP95", value: String(format: "%.4f m", c95))
            }
            if let hdop = dataExport.meanHDOP {
                StatRow(label: "Mean HDOP", value: String(format: "%.3f", hdop))
            }
        }
    }

    @ViewBuilder
    private var positionExportSection: some View {
        Section("Export") {
            Button {
                if let url = dataExport.exportPositionCSV() {
                    shareURL = url
                    showShareSheet = true
                }
            } label: {
                Label("Export CSV & Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var sampleCountView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(dataExport.sampleCount) / \(dataExport.targetSampleCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("samples")
                    .foregroundStyle(.secondary)
                Spacer()
                if dataExport.isRecording {
                    ProgressView()
                }
            }

            ProgressView(value: Double(dataExport.sampleCount),
                         total: Double(dataExport.targetSampleCount))
                .tint(dataExport.isRecording ? .red : .blue)
        }
    }

    @ViewBuilder
    private var discardButton: some View {
        if !dataExport.isRecording && dataExport.sampleCount > 0 {
            Button("Discard") {
                dataExport.discardRecording()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }
}

// MARK: - Helper Views

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
