import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var viewModel = PositioningViewModel()

    var body: some View {
        Group {
            if viewModel.bluetoothManager.bluetoothState == .poweredOn {
                TabView {
                    NavigationStack {
                        FloorPlanView(viewModel: viewModel)
                            .navigationTitle("Floor Plan")
                    }
                    .tabItem {
                        Label("Floor Plan", systemImage: "map")
                    }

                    NavigationStack {
                        AnchorListView(viewModel: viewModel)
                            .navigationTitle("Anchors")
                    }
                    .tabItem {
                        Label("Anchors", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    NavigationStack {
                        MeasureView(viewModel: viewModel)
                            .navigationTitle("Measure")
                    }
                    .tabItem {
                        Label("Measure", systemImage: "chart.bar.doc.horizontal")
                    }

                    NavigationStack {
                        SettingsView(viewModel: viewModel)
                            .navigationTitle("Settings")
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            } else {
                BluetoothWarningView(state: viewModel.bluetoothManager.bluetoothState)
            }
        }
    }
}

private struct BluetoothWarningView: View {
    let state: CBManagerState

    var body: some View {
        ContentUnavailableView {
            Label("Bluetooth Unavailable", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text(message)
        }
    }

    private var message: String {
        switch state {
        case .poweredOff:
            return "Bluetooth is turned off. Enable it in Settings."
        case .unauthorized:
            return "Bluetooth permission denied. Grant access in Settings > Privacy."
        case .unsupported:
            return "This device does not support Bluetooth Low Energy."
        default:
            return "Waiting for Bluetooth..."
        }
    }
}
