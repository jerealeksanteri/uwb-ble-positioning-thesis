import SwiftUI
import CoreBluetooth

struct AnchorListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        List {
            Section {
                ForEach(bluetoothManager.sortedAnchors) { anchor in
                    AnchorRow(anchor: anchor, bluetoothManager: bluetoothManager)
                }

                if bluetoothManager.sortedAnchors.isEmpty {
                    Text("No anchors found. Make sure boards are powered on.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("Anchors")
                    Spacer()
                    if bluetoothManager.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(bluetoothManager.isScanning ? "Stop Scan" : "Scan") {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                }
                .disabled(bluetoothManager.bluetoothState != .poweredOn)
            }
        }
    }
}

// MARK: - Anchor Row

private struct AnchorRow: View {
    @ObservedObject var anchor: Anchor
    let bluetoothManager: BluetoothManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: name + state badge
            HStack {
                Text(anchor.name)
                    .font(.headline)
                Spacer()
                StateBadge(state: anchor.state)
            }

            // Details
            HStack {
                Label("\(anchor.rssi) dBm", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if anchor.accessoryConfigData != nil {
                    Label("\(anchor.accessoryConfigData!.count) bytes", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Config data hex dump (when received)
            if let configData = anchor.accessoryConfigData {
                Text(configData.hexString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Connect / Disconnect button
            Button {
                switch anchor.state {
                case .discovered, .disconnected:
                    bluetoothManager.connect(anchor)
                case .connecting, .connected, .configReceived, .ranging:
                    bluetoothManager.disconnect(anchor)
                }
            } label: {
                Text(connectButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(connectButtonTint)
        }
        .padding(.vertical, 4)
    }

    private var connectButtonTitle: String {
        switch anchor.state {
        case .discovered, .disconnected: return "Connect"
        case .connecting: return "Connecting..."
        case .connected, .configReceived, .ranging: return "Disconnect"
        }
    }

    private var connectButtonTint: Color {
        switch anchor.state {
        case .discovered, .disconnected: return .blue
        case .connecting: return .gray
        case .connected, .configReceived, .ranging: return .red
        }
    }
}

// MARK: - State Badge

private struct StateBadge: View {
    let state: AnchorState

    var body: some View {
        Text(state.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch state {
        case .discovered: return .gray.opacity(0.2)
        case .connecting: return .orange.opacity(0.2)
        case .connected: return .blue.opacity(0.2)
        case .configReceived: return .green.opacity(0.2)
        case .ranging: return .purple.opacity(0.2)
        case .disconnected: return .red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .discovered: return .gray
        case .connecting: return .orange
        case .connected: return .blue
        case .configReceived: return .green
        case .ranging: return .purple
        case .disconnected: return .red
        }
    }
}

// MARK: - Data Hex Formatting

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
