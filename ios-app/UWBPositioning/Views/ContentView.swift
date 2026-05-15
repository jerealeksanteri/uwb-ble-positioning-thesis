import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var viewModel = PositioningViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.bluetoothManager.bluetoothState == .poweredOn {
                    AnchorListView(viewModel: viewModel)
                } else {
                    BluetoothWarningView(state: viewModel.bluetoothManager.bluetoothState)
                }
            }
            .navigationTitle("UWB Positioning")
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
