import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PositioningViewModel
    @FocusState private var focusedField: AnyHashable?

    private var configStore: AnchorConfigStore { viewModel.anchorConfigStore }
    private var bluetoothManager: BluetoothManager { viewModel.bluetoothManager }

    var body: some View {
        Form {
            anchorPositionsSection
            calibrationSection
            trilaterationSection
            actionsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    // MARK: - Anchor Positions

    @ViewBuilder
    private var anchorPositionsSection: some View {
        Section("Anchor Positions (meters)") {
            ForEach(configStore.configs) { config in
                AnchorPositionRow(
                    config: config,
                    focusedField: $focusedField,
                    onUpdate: { x, y in
                        configStore.updatePosition(anchorId: config.anchorId, x: x, y: y)
                    }
                )
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
                        NumericField(
                            value: config.distanceOffset,
                            placeholder: "0.0",
                            focusId: "offset-\(config.anchorId)",
                            focusedField: $focusedField,
                            onCommit: { newVal in
                                configStore.updateOffset(anchorId: config.anchorId, offset: newVal)
                            }
                        )
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
}

// MARK: - Anchor Position Row

/// Editable row for a single anchor's X/Y position.
/// Uses @State strings internally so the user can freely type, clear, and use commas.
private struct AnchorPositionRow: View {
    let config: AnchorConfig
    var focusedField: FocusState<AnyHashable?>.Binding
    let onUpdate: (Float, Float) -> Void

    @State private var xText: String = ""
    @State private var yText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Anchor \(config.anchorId)")
                .font(.headline)

            HStack {
                Text("X")
                    .frame(width: 20)
                TextField("0.0", text: $xText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: "x-\(config.anchorId)" as AnyHashable)
                    .onChange(of: focusedField.wrappedValue) { oldFocus, newFocus in
                        if oldFocus as? String == "x-\(config.anchorId)" && newFocus as? String != "x-\(config.anchorId)" {
                            commitX()
                        }
                    }

                Text("Y")
                    .frame(width: 20)
                TextField("0.0", text: $yText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: "y-\(config.anchorId)" as AnyHashable)
                    .onChange(of: focusedField.wrappedValue) { oldFocus, newFocus in
                        if oldFocus as? String == "y-\(config.anchorId)" && newFocus as? String != "y-\(config.anchorId)" {
                            commitY()
                        }
                    }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            xText = formatFloat(config.x)
            yText = formatFloat(config.y)
        }
        .onChange(of: config.x) { _, newVal in
            if focusedField.wrappedValue as? String != "x-\(config.anchorId)" {
                xText = formatFloat(newVal)
            }
        }
        .onChange(of: config.y) { _, newVal in
            if focusedField.wrappedValue as? String != "y-\(config.anchorId)" {
                yText = formatFloat(newVal)
            }
        }
    }

    private func commitX() {
        if let parsed = parseFloat(xText) {
            onUpdate(parsed, config.y)
        } else {
            xText = formatFloat(config.x)
        }
    }

    private func commitY() {
        if let parsed = parseFloat(yText) {
            onUpdate(config.x, parsed)
        } else {
            yText = formatFloat(config.y)
        }
    }
}

// MARK: - Numeric Field

/// A text field for Float values that lets the user freely edit without fighting SwiftUI bindings.
/// Commits the parsed value on focus loss; reverts to stored value if parsing fails.
private struct NumericField: View {
    let value: Float
    let placeholder: String
    let focusId: String
    var focusedField: FocusState<AnyHashable?>.Binding
    let onCommit: (Float) -> Void

    @State private var text: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            .focused(focusedField, equals: focusId as AnyHashable)
            .onChange(of: focusedField.wrappedValue) { oldFocus, newFocus in
                if oldFocus as? String == focusId && newFocus as? String != focusId {
                    commit()
                }
            }
            .onAppear { text = formatFloat(value) }
            .onChange(of: value) { _, newVal in
                if focusedField.wrappedValue as? String != focusId {
                    text = formatFloat(newVal)
                }
            }
    }

    private func commit() {
        if let parsed = parseFloat(text) {
            onCommit(parsed)
        } else {
            text = formatFloat(value)
        }
    }
}

// MARK: - Helpers

private func formatFloat(_ value: Float) -> String {
    let s = String(format: "%.2f", value)
    // Strip trailing zeros: "1.00" → "1", "1.50" → "1.5"
    if s.contains(".") {
        var trimmed = s
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }
    return s
}

private func parseFloat(_ text: String) -> Float? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    return Float(normalized)
}
