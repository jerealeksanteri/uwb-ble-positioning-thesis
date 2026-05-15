import Foundation
import Combine
import CoreBluetooth

/// Connection and ranging state of an anchor
enum AnchorState: String {
    case discovered     = "Discovered"
    case connecting     = "Connecting"
    case connected      = "Connected"
    case configReceived = "Config OK"
    case ranging        = "Ranging"
    case disconnected   = "Disconnected"
}

/// Represents a single UWB anchor (DWM3001CDK board)
class Anchor: Identifiable, ObservableObject {
    /// CBPeripheral identifier — stable across app launches
    let id: UUID

    /// Anchor number (1, 2, or 3), parsed from BLE name
    let anchorId: Int

    /// BLE advertised name (e.g. "UWB-Anchor-1")
    let name: String

    /// CoreBluetooth peripheral reference (retained to keep connection alive)
    var peripheral: CBPeripheral?

    /// Current state
    @Published var state: AnchorState = .discovered

    /// Last observed RSSI (dBm)
    @Published var rssi: Int = 0

    /// Raw Accessory Configuration Data received from anchor (without message ID prefix)
    @Published var accessoryConfigData: Data?

    // MARK: - GATT characteristic references (set during service discovery)

    /// QNIS RX characteristic — write commands to anchor
    var rxCharacteristic: CBCharacteristic?

    /// QNIS TX characteristic — receive notifications from anchor
    var txCharacteristic: CBCharacteristic?

    init(peripheral: CBPeripheral, anchorId: Int, name: String) {
        self.id = peripheral.identifier
        self.anchorId = anchorId
        self.name = name
        self.peripheral = peripheral
    }
}
