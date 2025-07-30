import Foundation
import Combine

// MARK: - C FFI Bridge

typealias LoraManagerPtr = UnsafeMutableRawPointer

// C structure definitions (must match Rust)
struct CDeviceInfo {
    let id: UnsafeMutablePointer<CChar>
    let name: UnsafeMutablePointer<CChar>
    let path: UnsafeMutablePointer<CChar>
    let deviceType: UInt32
    let manufacturer: UnsafeMutablePointer<CChar>?
    let vendorId: UnsafeMutablePointer<CChar>?
    let productId: UnsafeMutablePointer<CChar>?
    let isAvailable: Bool
}

struct CDeviceArray {
    let devices: UnsafeMutablePointer<CDeviceInfo>?
    let count: Int
}

struct CNodeInfo {
    let id: UnsafeMutablePointer<CChar>
    let name: UnsafeMutablePointer<CChar>
    let shortName: UnsafeMutablePointer<CChar>
    let isOnline: Bool
}

struct CNodeArray {
    let nodes: UnsafeMutablePointer<CNodeInfo>?
    let count: Int
}

// External C functions from Rust library
@_silgen_name("lora_comms_init")
func loraCommsInit() -> LoraManagerPtr?

@_silgen_name("lora_comms_cleanup")
func loraCommsCleanup(_ manager: LoraManagerPtr)

@_silgen_name("lora_comms_scan_devices")
func loraCommsScanDevices(_ manager: LoraManagerPtr) -> CDeviceArray

@_silgen_name("lora_comms_connect_device")
func loraCommsConnectDevice(_ manager: LoraManagerPtr, _ devicePath: UnsafePointer<CChar>, _ deviceType: UInt32) -> UnsafeMutablePointer<CChar>?

@_silgen_name("lora_comms_send_message")
func loraCommsSendMessage(_ manager: LoraManagerPtr, _ deviceId: UnsafePointer<CChar>, _ message: UnsafePointer<CChar>, _ destination: UnsafePointer<CChar>?) -> Bool

@_silgen_name("lora_comms_get_nodes")
func loraCommsGetNodes(_ manager: LoraManagerPtr, _ deviceId: UnsafePointer<CChar>) -> CNodeArray

@_silgen_name("lora_comms_free_device_array")
func loraCommsFreeDeviceArray(_ array: CDeviceArray)

@_silgen_name("lora_comms_free_node_array")
func loraCommsFreeNodeArray(_ array: CNodeArray)

@_silgen_name("lora_comms_free_string")
func loraCommsFreeString(_ string: UnsafeMutablePointer<CChar>)

// MARK: - Device Manager

public class DeviceManager: ObservableObject {
    private var manager: LoraManagerPtr?
    private var activeDeviceId: String?
    private var messageTimer: Timer?
    
    @Published public var appState = AppState()
    
    public init() {
        print("[DeviceManager] Initializing DeviceManager")
        self.manager = loraCommsInit()
        if self.manager == nil {
            print("[DeviceManager] ERROR: Failed to initialize Rust core library")
        } else {
            print("[DeviceManager] SUCCESS: Rust core library initialized with manager: \(self.manager!)")
        }
    }
    
    deinit {
        if let manager = manager {
            loraCommsCleanup(manager)
        }
    }
    
    // MARK: - Device Scanning
    
    public func scanDevices() async {
        guard let manager = manager else {
            print("[DeviceManager] ERROR: Manager not initialized")
            return
        }
        
        print("[DeviceManager] Starting device scan with manager: \(manager)")
        
        await MainActor.run {
            appState.isScanning = true
        }
        
        // Perform scanning on background queue
        let devices = await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                print("[DeviceManager] About to call loraCommsScanDevices")
                let deviceArray = loraCommsScanDevices(manager)
                print("[DeviceManager] loraCommsScanDevices returned. Count: \(deviceArray.count), Devices ptr: \(String(describing: deviceArray.devices))")
                
                var devices: [DeviceInfo] = []
                
                if let devicePtr = deviceArray.devices {
                    print("[DeviceManager] Processing \(deviceArray.count) devices")
                    for i in 0..<deviceArray.count {
                        let cDevice = devicePtr[i]
                        
                        let id = String(cString: cDevice.id)
                        let name = String(cString: cDevice.name)
                        let path = String(cString: cDevice.path)
                        let deviceType = DeviceType(rawValue: Int(cDevice.deviceType)) ?? .serial
                        let manufacturer = cDevice.manufacturer != nil ? String(cString: cDevice.manufacturer!) : nil
                        let vendorId = cDevice.vendorId != nil ? String(cString: cDevice.vendorId!) : nil
                        let productId = cDevice.productId != nil ? String(cString: cDevice.productId!) : nil
                        
                        print("[DeviceManager] Device \(i): \(name) at \(path)")
                        
                        let deviceInfo = DeviceInfo(
                            id: id,
                            name: name,
                            path: path,
                            deviceType: deviceType,
                            manufacturer: manufacturer,
                            vendorId: vendorId,
                            productId: productId,
                            isAvailable: cDevice.isAvailable
                        )
                        
                        devices.append(deviceInfo)
                    }
                } else {
                    print("[DeviceManager] Device array is null or count is 0")
                }
                
                loraCommsFreeDeviceArray(deviceArray)
                print("[DeviceManager] Final device count: \(devices.count)")
                continuation.resume(returning: devices)
            }
        }
        
        await MainActor.run {
            print("[DeviceManager] Setting \(devices.count) devices in app state")
            appState.availableDevices = devices
            appState.isScanning = false
        }
    }
    
    // MARK: - Device Connection
    
    public func connectDevice(_ deviceInfo: DeviceInfo) async -> Bool {
        guard let manager = manager else {
            print("Manager not initialized")
            return false
        }
        
        return await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let success = deviceInfo.path.withCString { pathPtr in
                    if let deviceIdPtr = loraCommsConnectDevice(manager, pathPtr, UInt32(deviceInfo.deviceType.rawValue)) {
                        let deviceId = String(cString: deviceIdPtr)
                        loraCommsFreeString(deviceIdPtr)
                        
                        DispatchQueue.main.async {
                            self.activeDeviceId = deviceId
                            
                            var connection = DeviceConnection(deviceInfo: deviceInfo)
                            connection.setConnected()
                            
                            self.appState.connections.removeAll { $0.deviceInfo.id == deviceInfo.id }
                            self.appState.connections.append(connection)
                            
                            // Start listening for messages
                            self.startMessagePolling()
                        }
                        
                        return true
                    }
                    return false
                }
                
                continuation.resume(returning: success)
            }
        }
    }
    
    public func disconnectDevice(_ deviceInfo: DeviceInfo) {
        // Remove connection
        appState.connections.removeAll { $0.deviceInfo.id == deviceInfo.id }
        
        if activeDeviceId != nil {
            activeDeviceId = nil
            stopMessagePolling()
        }
    }
    
    // MARK: - Message Handling
    
    public func sendMessage(_ text: String, to destination: String? = nil) async -> Bool {
        guard let manager = manager,
              let deviceId = activeDeviceId else {
            print("No active device connection")
            return false
        }
        
        return await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let success = text.withCString { textPtr in
                    deviceId.withCString { deviceIdPtr in
                        if let dest = destination {
                            return dest.withCString { destPtr in
                                loraCommsSendMessage(manager, deviceIdPtr, textPtr, destPtr)
                            }
                        } else {
                            return loraCommsSendMessage(manager, deviceIdPtr, textPtr, nil)
                        }
                    }
                }
                
                if success {
                    DispatchQueue.main.async {
                        let message = MeshMessage.outgoing(text: text, destination: destination)
                        self.appState.messages.append(message)
                    }
                }
                
                continuation.resume(returning: success)
            }
        }
    }
    
    public func getNodes() async {
        guard let manager = manager,
              let deviceId = activeDeviceId else {
            return
        }
        
        let nodes = await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let nodeArray = deviceId.withCString { deviceIdPtr in
                    loraCommsGetNodes(manager, deviceIdPtr)
                }
                
                var nodes: [NodeInfo] = [NodeInfo.broadcast] // Always include broadcast
                
                if let nodePtr = nodeArray.nodes {
                    for i in 0..<nodeArray.count {
                        let cNode = nodePtr[i]
                        
                        let id = String(cString: cNode.id)
                        let name = String(cString: cNode.name)
                        let shortName = String(cString: cNode.shortName)
                        
                        let nodeInfo = NodeInfo(
                            id: id,
                            name: name,
                            shortName: shortName,
                            isOnline: cNode.isOnline
                        )
                        
                        nodes.append(nodeInfo)
                    }
                }
                
                loraCommsFreeNodeArray(nodeArray)
                continuation.resume(returning: nodes)
            }
        }
        
        await MainActor.run {
            appState.nodes = nodes
        }
    }
    
    // MARK: - Message Polling (Simulation)
    
    private func startMessagePolling() {
        stopMessagePolling()
        
        // In a real implementation, this would be handled by the Rust library
        // For now, we simulate periodic message checking
        messageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Simulate receiving messages occasionally
            if Int.random(in: 0...100) < 5 { // 5% chance every second
                let message = MeshMessage(
                    text: "Hello from node \(Int.random(in: 1000...9999))",
                    sender: "Node\(Int.random(in: 10...99))",
                    destination: nil,
                    isFromMe: false
                )
                
                DispatchQueue.main.async {
                    self.appState.messages.append(message)
                }
            }
        }
    }
    
    private func stopMessagePolling() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    // MARK: - Convenience Methods
    
    public var isConnected: Bool {
        return appState.activeConnection != nil
    }
    
    public var connectedDevice: DeviceInfo? {
        return appState.activeConnection?.deviceInfo
    }
}
