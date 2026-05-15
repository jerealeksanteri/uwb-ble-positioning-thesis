import CoreBluetooth

/// BLE UUIDs matching the Qorvo QANI firmware (ble_qnis.c, ble_anis.c)
enum BLEConstants {
    // MARK: - QNIS Service (Qorvo NI Service) — primary command/response channel
    // Base UUID: 2E930000-6A61-11ED-A1EB-0242AC120002

    /// QNIS service UUID (advertised by anchors)
    static let qnisServiceUUID = CBUUID(string: "2E938FD0-6A61-11ED-A1EB-0242AC120002")

    /// RX characteristic — write commands TO anchor
    static let qnisRxCharUUID  = CBUUID(string: "2E93998A-6A61-11ED-A1EB-0242AC120002")

    /// TX characteristic — receive notifications FROM anchor
    static let qnisTxCharUUID  = CBUUID(string: "2E939AF2-6A61-11ED-A1EB-0242AC120002")

    // MARK: - NI Message IDs (from niq.h SampleAppMessageId enum)

    /// iPhone → Anchor: request Accessory Configuration Data
    static let messageIdInit: UInt8 = 0x0A

    /// Anchor → iPhone: Accessory Configuration Data response
    static let messageIdAccessoryConfigData: UInt8 = 0x01

    /// iPhone → Anchor: send shareable config + start UWB
    static let messageIdConfigureAndStart: UInt8 = 0x0B

    /// Anchor → iPhone: UWB session started ACK
    static let messageIdUwbDidStart: UInt8 = 0x02

    /// iPhone → Anchor: stop UWB session
    static let messageIdStop: UInt8 = 0x0C

    /// Anchor → iPhone: UWB session stopped ACK
    static let messageIdUwbDidStop: UInt8 = 0x03

    // MARK: - Device Discovery

    /// BLE name prefix for filtering anchor devices
    static let anchorNamePrefix = "UWB-Anchor-"
}
