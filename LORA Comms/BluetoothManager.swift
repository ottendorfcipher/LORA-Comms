import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Bluetooth Manager following Meshtastic-Apple patterns

@MainActor
public class BluetoothManager: NSObject, ObservableObject {
    // Meshtastic Bluetooth service and characteristic UUIDs
    // These UUIDs are used by Meshtastic devices for Bluetooth communication
    static let meshtasticServiceUUID = CBUUID(string: "6BA1B218-15A8-461F-9FA8-5DCAE273EAFD")
    static let toRadioCharacteristicUUID = CBUUID(string: "F75C76D2-129E-4DAD-A1DD-7866124401E7") 
    static let fromRadioCharacteristicUUID = CBUUID(string: "8BA2BCC2-EE02-4A55-A531-C525C5E454D5")
    static let fromNumCharacteristicUUID = CBUUID(string: "ED9DA18C-A800-4F66-A670-AA7547E34453")
    
    // Core Bluetooth objects
    private var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    private var toRadioCharacteristic: CBCharacteristic?
    private var fromRadioCharacteristic: CBCharacteristic?
    private var fromNumCharacteristic: CBCharacteristic?
    
    // Published state
    @Published public var isScanning = false
    @Published public var discoveredDevices: [MeshtasticDevice] = []
    @Published public var connectionState: BluetoothConnectionState = .disconnected
    @Published public var signalStrength: Int?
    @Published public var lastPacketTime: Date?
    @Published public var bluetoothState: CBManagerState = .unknown
    @Published public var connectionProgress: ConnectionProgress = .idle
    @Published public var lastError: BluetoothError?
    @Published public var connectedDevices: [MeshtasticDevice] = []
    @Published public var isBackgroundScanning = false
    
    // Connection progress
    public enum ConnectionProgress {
        case idle
        case scanning
        case connecting
        case discoveringServices
        case discoveringCharacteristics
        case establishingConnection
        case completed
        
        var description: String {
            switch self {
            case .idle: return "Idle"
            case .scanning: return "Scanning"
            case .connecting: return "Connecting"
            case .discoveringServices: return "Discovering Services"
            case .discoveringCharacteristics: return "Discovering Characteristics"
            case .establishingConnection: return "Establishing Connection"
            case .completed: return "Completed"
            }
        }
    }   

    public enum BluetoothError: Error, CustomStringConvertible {
        case bluetoothNotAvailable
        case peripheralNotFound
        case characteristicNotFound
        case unableToConnect
        case dataTransmissionError

        public var description: String {
            switch self {
            case .bluetoothNotAvailable: return "Bluetooth is not available."
            case .peripheralNotFound: return "Peripheral not found."
            case .characteristicNotFound: return "Required characteristic not found."
            case .unableToConnect: return "Unable to establish connection."
            case .dataTransmissionError: return "Error transmitting data."
            }
        }
    }

    // Message handling
    private var incomingBuffer = Data()
    private let maxPacketSize = 512
    
    public override init() {
        super.init()
        // Initialize central manager on the main thread
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Interface

    // Auto-reconnect toggles
    private var autoReconnect = true
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("[BluetoothManager] Bluetooth not available")
            lastError = .bluetoothNotAvailable
            return
        }
        
        print("[BluetoothManager] Starting scan for Meshtastic devices")
        isScanning = true
        connectionProgress = .scanning
        discoveredDevices.removeAll()
        
        centralManager.scanForPeripherals(
            withServices: [Self.meshtasticServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto-stop scanning after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    public func stopScanning() {
        print("[BluetoothManager] Stopping scan")
        centralManager.stopScan()
        isScanning = false
        connectionProgress = .idle
    }
    
    public func connect(to device: MeshtasticDevice) {
        guard let peripheral = device.peripheral else {
            print("[BluetoothManager] No peripheral found for device")
            lastError = .peripheralNotFound
            return
        }
        
        print("[BluetoothManager] Connecting to \(device.name)")
        connectionState = .connecting
        connectionProgress = .connecting
        centralManager.connect(peripheral, options: nil)
        
        // Monitor RSSI for signal strength evaluation
        peripheral.readRSSI()
    }
    
    public func disconnect() {
        guard let peripheral = connectedPeripheral else {
            print("[BluetoothManager] No connected peripheral to disconnect")
            return
        }
        
        print("[BluetoothManager] Disconnecting from \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
        connectionProgress = .idle
        
        // Attempt automatic reconnect if enabled
        if autoReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.startScanning()
            }
        }
    }
    
    public func sendToRadio(_ data: Data) async -> Bool {
        guard let characteristic = toRadioCharacteristic,
              let peripheral = connectedPeripheral,
              connectionState == .connected else {
            print("[BluetoothManager] Not connected or missing characteristic")
            lastError = .characteristicNotFound
            return false
        }
        
        print("[BluetoothManager] Sending \(data.count) bytes to radio")
        
        // Split data into chunks if larger than MTU
        let chunkSize = min(peripheral.maximumWriteValueLength(for: .withoutResponse), maxPacketSize)
        
        for i in stride(from: 0, to: data.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, data.count)
            let chunk = data.subdata(in: i..<endIndex)
            
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            
            // Small delay between chunks to prevent overwhelming the device
            if endIndex < data.count {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }

        connectionProgress = .completed
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupCharacteristics(for peripheral: CBPeripheral) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.meshtasticServiceUUID }) else {
            print("[BluetoothManager] Meshtastic service not found")
            return
        }
        
        // Find characteristics
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.toRadioCharacteristicUUID:
                toRadioCharacteristic = characteristic
                print("[BluetoothManager] Found toRadio characteristic")
                
            case Self.fromRadioCharacteristicUUID:
                fromRadioCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("[BluetoothManager] Found fromRadio characteristic, enabled notifications")
                
            case Self.fromNumCharacteristicUUID:
                fromNumCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("[BluetoothManager] Found fromNum characteristic, enabled notifications")
                
            default:
                break
            }
        }
        
        // Check if we have all required characteristics
        if toRadioCharacteristic != nil && fromRadioCharacteristic != nil {
            connectionState = .connected
            print("[BluetoothManager] Successfully connected and configured")
        } else {
            print("[BluetoothManager] Missing required characteristics")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        incomingBuffer.append(data)
        lastPacketTime = Date()
        
        // Process complete messages from buffer
        // In a real implementation, this would parse protobuf messages
        print("[BluetoothManager] Received \(data.count) bytes, buffer size: \(incomingBuffer.count)")
        
        // For now, just pass raw data to message processor
        // TODO: Implement protobuf parsing and message handling
        processIncomingMessage(data)
    }
    
    private func processIncomingMessage(_ data: Data) {
        // This would normally parse the protobuf message and update the app state
        // For now, just log the received data
        print("[BluetoothManager] Processing message: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        // TODO: 
        // 1. Parse protobuf MeshPacket
        // 2. Decode payload based on message type
        // 3. Update app state (messages, nodes, telemetry, etc.)
        // 4. Trigger UI updates
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            print("[BluetoothManager] Bluetooth state: \(state.description)")
            self.bluetoothState = state
            
            switch state {
            case .poweredOn:
                // Ready to scan
                self.lastError = nil
                break
            case .poweredOff:
                self.connectionState = .disconnected
                self.isScanning = false
                self.lastError = .bluetoothNotAvailable
            case .unauthorized, .unsupported:
                self.connectionState = .disconnected
                self.isScanning = false
                self.lastError = .bluetoothNotAvailable
            default:
                break
            }
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let device = MeshtasticDevice(
            peripheral: peripheral,
            name: peripheral.name ?? "Unknown Meshtastic Device",
            rssi: RSSI.intValue
        )
        
        Task { @MainActor in
            // Update existing device or add new one
            if let existingIndex = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[existingIndex] = device
            } else {
                self.discoveredDevices.append(device)
            }
            
            print("[BluetoothManager] Discovered: \(device.name) (RSSI: \(RSSI))")
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[BluetoothManager] Connected to \(peripheral.name ?? "Unknown")")
            
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            self.connectionProgress = .discoveringServices
            
            // Discover services
            peripheral.discoverServices([Self.meshtasticServiceUUID])
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[BluetoothManager] Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[BluetoothManager] Disconnected from \(peripheral.name ?? "Unknown")")
            
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
            self.toRadioCharacteristic = nil
            self.fromRadioCharacteristic = nil
            self.fromNumCharacteristic = nil
            self.incomingBuffer.removeAll()
            
            if let error = error {
                print("[BluetoothManager] Disconnection error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[BluetoothManager] Service discovery error: \(error.localizedDescription)")
                self.lastError = .unableToConnect
                return
            }
            
            guard let services = peripheral.services else {
                print("[BluetoothManager] No services found")
                self.lastError = .unableToConnect
                return
            }
            
            self.connectionProgress = .discoveringCharacteristics
            
            for service in services {
                if service.uuid == Self.meshtasticServiceUUID {
                    print("[BluetoothManager] Found Meshtastic service")
                    peripheral.discoverCharacteristics([
                        Self.toRadioCharacteristicUUID,
                        Self.fromRadioCharacteristicUUID,
                        Self.fromNumCharacteristicUUID
                    ], for: service)
                }
            }
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[BluetoothManager] Characteristic discovery error: \(error.localizedDescription)")
                self.lastError = .characteristicNotFound
                return
            }
            
            self.connectionProgress = .establishingConnection
            self.setupCharacteristics(for: peripheral)
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BluetoothManager] Characteristic update error: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value, !data.isEmpty else {
            return
        }
        
        Task { @MainActor in
            self.handleIncomingData(data)
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BluetoothManager] Notification state error: \(error.localizedDescription)")
            return
        }
        
        print("[BluetoothManager] Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            let rssiValue = RSSI.intValue
            Task { @MainActor in
                self.signalStrength = rssiValue
            }
        }
    }
}

// MARK: - Supporting Types

public struct MeshtasticDevice: Identifiable, Hashable {
    public let id: String
    public let peripheral: CBPeripheral?
    public let name: String
    public let rssi: Int
    public let discoveredAt: Date
    
    public init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.id = peripheral.identifier.uuidString
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.discoveredAt = Date()
    }
    
    // Initializer for preview/testing purposes
    public init(peripheral: CBPeripheral?, name: String, rssi: Int) {
        self.id = peripheral?.identifier.uuidString ?? UUID().uuidString
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.discoveredAt = Date()
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MeshtasticDevice, rhs: MeshtasticDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    public var deviceInfo: DeviceInfo {
        return DeviceInfo(
            id: id,
            name: name,
            path: "bluetooth://\(id)",
            deviceType: .bluetooth,
            manufacturer: "Meshtastic",
            isAvailable: true
        )
    }
    
    public var signalQuality: String {
        switch rssi {
        case -50...0: return "Excellent"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        default: return "Poor"
        }
    }
}

public enum BluetoothConnectionState: String, CaseIterable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
    
    public var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

// MARK: - CBManagerState Extension

extension CBManagerState {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "Unknown State"
        }
    }
}
