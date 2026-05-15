import Combine
import CoreBluetooth
import os

/// Manages BLE scanning, connection, GATT service discovery, and NI message exchange with UWB anchors.
///
/// Interaction sequence per anchor (from ble_niq.c):
/// 1. Connect → discover QNIS service → discover RX/TX characteristics
/// 2. Enable notifications on TX characteristic
/// 3. Write MessageId_init (0x0A) to RX → receive ACD via TX notification
/// 4. (Phase 5) Write MessageId_configure_and_start (0x0B) + shareable config to RX
/// 5. (Phase 5) Receive MessageId_accessoryUwbDidStart (0x02) ACK
class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private let logger = Logger(subsystem: "com.jereniemi.uwb-positioning", category: "Bluetooth")

    /// Discovered and connected anchors keyed by CBPeripheral identifier
    @Published var anchors: [UUID: Anchor] = [:]

    /// Whether BLE scanning is active
    @Published var isScanning = false

    /// Current Bluetooth adapter state
    @Published var bluetoothState: CBManagerState = .unknown

    /// Callback fired when accessory config data is received from an anchor.
    /// Phase 5 will use this to trigger NI session creation.
    var onAccessoryConfigDataReceived: ((Anchor) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Sorted list of anchors for UI display
    var sortedAnchors: [Anchor] {
        anchors.values.sorted { $0.anchorId < $1.anchorId }
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth not powered on (state: \(self.centralManager.state.rawValue))")
            return
        }
        logger.info("Starting BLE scan for QNIS service")
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.qnisServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        logger.info("Stopping BLE scan")
        centralManager.stopScan()
        isScanning = false
    }

    func connect(_ anchor: Anchor) {
        guard let peripheral = anchor.peripheral else { return }
        logger.info("Connecting to \(anchor.name)")
        anchor.state = .connecting
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(_ anchor: Anchor) {
        guard let peripheral = anchor.peripheral else { return }
        logger.info("Disconnecting from \(anchor.name)")
        centralManager.cancelPeripheralConnection(peripheral)
    }

    /// Send MessageId_init to request Accessory Configuration Data from anchor
    func requestAccessoryConfigData(_ anchor: Anchor) {
        guard let peripheral = anchor.peripheral,
              let rxChar = anchor.rxCharacteristic else {
            logger.error("Cannot request ACD: missing peripheral or RX characteristic for \(anchor.name)")
            return
        }
        logger.info("Requesting ACD from \(anchor.name)")
        let data = Data([BLEConstants.messageIdInit])
        peripheral.writeValue(data, for: rxChar, type: .withResponse)
    }

    /// Send shareable configuration data + start UWB (Phase 5)
    func sendConfigureAndStart(_ anchor: Anchor, shareableData: Data) {
        guard let peripheral = anchor.peripheral,
              let rxChar = anchor.rxCharacteristic else {
            logger.error("Cannot send configure_and_start: missing peripheral or RX for \(anchor.name)")
            return
        }
        logger.info("Sending configure_and_start to \(anchor.name) (\(shareableData.count) bytes)")
        var payload = Data([BLEConstants.messageIdConfigureAndStart])
        payload.append(shareableData)
        peripheral.writeValue(payload, for: rxChar, type: .withResponse)
    }

    /// Send stop command (Phase 5)
    func sendStop(_ anchor: Anchor) {
        guard let peripheral = anchor.peripheral,
              let rxChar = anchor.rxCharacteristic else { return }
        logger.info("Sending stop to \(anchor.name)")
        let data = Data([BLEConstants.messageIdStop])
        peripheral.writeValue(data, for: rxChar, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        logger.info("Bluetooth state: \(central.state.rawValue)")

        if central.state == .poweredOn {
            startScanning()
        } else {
            isScanning = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                         didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any],
                         rssi RSSI: NSNumber) {
        guard let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              name.hasPrefix(BLEConstants.anchorNamePrefix) else {
            return
        }

        // Parse anchor ID from name (e.g. "UWB-Anchor-2" → 2)
        let idString = name.replacingOccurrences(of: BLEConstants.anchorNamePrefix, with: "")
        guard let anchorId = Int(idString) else { return }

        if let existing = anchors[peripheral.identifier] {
            existing.rssi = RSSI.intValue
        } else {
            logger.info("Discovered \(name) (RSSI: \(RSSI.intValue))")
            let anchor = Anchor(peripheral: peripheral, anchorId: anchorId, name: name)
            anchor.rssi = RSSI.intValue
            anchors[peripheral.identifier] = anchor
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let anchor = anchors[peripheral.identifier] else { return }
        logger.info("Connected to \(anchor.name)")
        anchor.state = .connected
        peripheral.delegate = self
        peripheral.discoverServices([BLEConstants.qnisServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }
        logger.error("Failed to connect to \(anchor.name): \(error?.localizedDescription ?? "unknown")")
        anchor.state = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }
        logger.info("Disconnected from \(anchor.name)")
        anchor.state = .disconnected
        anchor.rxCharacteristic = nil
        anchor.txCharacteristic = nil
        anchor.accessoryConfigData = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }

        if let error {
            logger.error("Service discovery failed for \(anchor.name): \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == BLEConstants.qnisServiceUUID {
                logger.info("Found QNIS service on \(anchor.name)")
                peripheral.discoverCharacteristics(
                    [BLEConstants.qnisRxCharUUID, BLEConstants.qnisTxCharUUID],
                    for: service
                )
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }

        if let error {
            logger.error("Characteristic discovery failed for \(anchor.name): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == BLEConstants.qnisRxCharUUID {
                anchor.rxCharacteristic = char
                logger.info("Found QNIS RX characteristic on \(anchor.name)")
            } else if char.uuid == BLEConstants.qnisTxCharUUID {
                anchor.txCharacteristic = char
                logger.info("Found QNIS TX characteristic on \(anchor.name)")
                // Enable notifications on TX to receive responses from anchor
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }

        if let error {
            logger.error("Notification state update failed for \(anchor.name): \(error.localizedDescription)")
            return
        }

        if characteristic.uuid == BLEConstants.qnisTxCharUUID && characteristic.isNotifying {
            logger.info("TX notifications enabled on \(anchor.name) — requesting ACD")
            // Automatically request Accessory Configuration Data
            requestAccessoryConfigData(anchor)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }

        if let error {
            logger.error("Value update failed for \(anchor.name): \(error.localizedDescription)")
            return
        }

        guard characteristic.uuid == BLEConstants.qnisTxCharUUID,
              let data = characteristic.value,
              !data.isEmpty else {
            return
        }

        let messageId = data[0]

        switch messageId {
        case BLEConstants.messageIdAccessoryConfigData:
            // ACD response: [0x01][majorVersion(2)][minorVersion(2)][updateRate(1)][rfu(10)][configLen(1)][configData(...)]
            let acdPayload = data.dropFirst() // Strip message ID byte
            anchor.accessoryConfigData = Data(acdPayload)
            anchor.state = .configReceived
            logger.info("Received ACD from \(anchor.name) (\(acdPayload.count) bytes)")
            onAccessoryConfigDataReceived?(anchor)

        case BLEConstants.messageIdUwbDidStart:
            logger.info("UWB started ACK from \(anchor.name)")
            anchor.state = .ranging

        case BLEConstants.messageIdUwbDidStop:
            logger.info("UWB stopped ACK from \(anchor.name)")
            anchor.state = .connected

        default:
            logger.debug("Unknown message ID 0x\(String(format: "%02X", messageId)) from \(anchor.name)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let anchor = anchors[peripheral.identifier] else { return }
        if let error {
            logger.error("Write failed for \(anchor.name): \(error.localizedDescription)")
        }
    }
}
