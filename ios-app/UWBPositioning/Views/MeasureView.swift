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
            configSection

            recordingSection

            if dataExport.sampleCount > 0 {
                statisticsSection
            }

            if !dataExport.samples.isEmpty && !dataExport.isRecording {
                exportSection
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Config Section

    @ViewBuilder
    private var configSection: some View {
        Section("Configuration") {
            Picker("Anchor", selection: $dataExport.recordingAnchorId) {
                Text("Select...").tag(nil as Int?)
                ForEach(rangingAnchors) { anchor in
                    Text(anchor.name).tag(anchor.anchorId as Int?)
                }
            }
            .disabled(dataExport.isRecording)

            HStack {
                Text("True Distance")
                Spacer()
                TextField("meters", value: $dataExport.trueDistance, format: .number)
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
                    value: $dataExport.targetSampleCount,
                    in: 10...500, step: 10)
                .disabled(dataExport.isRecording)
        }
    }

    // MARK: - Recording Section

    @ViewBuilder
    private var recordingSection: some View {
        Section("Recording") {
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

                if !dataExport.isRecording && dataExport.sampleCount > 0 {
                    Button("Discard") {
                        dataExport.discardRecording()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private var statisticsSection: some View {
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

    // MARK: - Export Section

    @ViewBuilder
    private var exportSection: some View {
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
