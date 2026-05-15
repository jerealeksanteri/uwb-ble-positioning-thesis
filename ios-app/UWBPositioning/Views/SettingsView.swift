import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PositioningViewModel

    private var configStore: AnchorConfigStore { viewModel.anchorConfigStore }
    private var bluetoothManager: BluetoothManager { viewModel.bluetoothManager }

    var body: some View {
        Form {
            anchorPositionsSection
            calibrationSection
            trilaterationSection
            actionsSection
        }
    }

    // MARK: - Anchor Positions

    @ViewBuilder
    private var anchorPositionsSection: some View {
        Section("Anchor Positions (meters)") {
            ForEach(configStore.configs) { config in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anchor \(config.anchorId)")
                        .font(.headline)

                    HStack {
                        Text("X")
                            .frame(width: 20)
                        TextField("X", value: bindingForX(config.anchorId), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Text("Y")
                            .frame(width: 20)
                        TextField("Y", value: bindingForY(config.anchorId), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Calibration Offsets

    @ViewBuilder
    private var calibrationSection: some View {
        Section {
            ForEach(configStore.configs) { config in
                let anchor = bluetoothManager.anchors.values.first { $0.anchorId == config.anchorId }
                let isRanging = anchor?.state == .ranging

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Anchor \(config.anchorId)")
                            .font(.headline)
                        Spacer()
                        if isRanging, let raw = anchor?.distance {
                            let calibrated = raw + config.distanceOffset
                            Text(String(format: "%.3f → %.3f m", raw, calibrated))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Offset")
                            .frame(width: 50, alignment: .leading)
                        TextField("0.0", value: bindingForOffset(config.anchorId), format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Distance Calibration Offsets")
        } footer: {
            Text("Positive offset: anchor reads too short. Negative: reads too long.")
        }
    }

    // MARK: - Trilateration Settings

    @ViewBuilder
    private var trilaterationSection: some View {
        Section("Trilateration") {
            Toggle("Weighted (closer anchors trusted more)", isOn: $viewModel.useWeightedTrilateration)

            if let hdop = viewModel.currentHDOP {
                HStack {
                    Text("Current HDOP")
                    Spacer()
                    Text(String(format: "%.2f", hdop))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(hdop < 2 ? .green : hdop < 5 ? .orange : .red)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button("Reset to Defaults", role: .destructive) {
                configStore.resetToDefaults()
            }
        }
    }

    // MARK: - Bindings

    private func bindingForX(_ anchorId: Int) -> Binding<Float> {
        Binding(
            get: { configStore.config(for: anchorId)?.x ?? 0 },
            set: { newVal in
                if let config = configStore.config(for: anchorId) {
                    configStore.updatePosition(anchorId: anchorId, x: newVal, y: config.y)
                }
            }
        )
    }

    private func bindingForY(_ anchorId: Int) -> Binding<Float> {
        Binding(
            get: { configStore.config(for: anchorId)?.y ?? 0 },
            set: { newVal in
                if let config = configStore.config(for: anchorId) {
                    configStore.updatePosition(anchorId: anchorId, x: config.x, y: newVal)
                }
            }
        )
    }

    private func bindingForOffset(_ anchorId: Int) -> Binding<Float> {
        Binding(
            get: { configStore.config(for: anchorId)?.distanceOffset ?? 0 },
            set: { newVal in configStore.updateOffset(anchorId: anchorId, offset: newVal) }
        )
    }
}
