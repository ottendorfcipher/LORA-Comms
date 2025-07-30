import Foundation
import Combine
import CoreBluetooth
import IOBluetooth

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
@_silgen_name("lora_comms_test")
func loraCommsTest() -> UnsafeMutablePointer<CChar>?

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
    @Published private(set) var activeDeviceId: String?
    private var messageTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let redisCache = RedisCache()
    
    // Flattened state properties for better SwiftUI reactivity
    @Published public var availableDevices: [DeviceInfo] = [] {
        didSet {
            print("[DeviceManager] availableDevices updated: \(availableDevices.count) devices")
            NSLog("[DeviceManager] availableDevices updated: %d devices", availableDevices.count)
            for (index, device) in availableDevices.enumerated() {
                print("[DeviceManager]   Device \(index): \(device.name)")
                NSLog("[DeviceManager]   Device %d: %@", index, device.name)
            }
        }
    }
    @Published public var connections: [DeviceConnection] = []
    @Published public var messages: [MeshMessage] = []
    @Published public var nodes: [NodeInfo] = []
    @Published public var selectedNodeId: String = "broadcast"
    @Published public var isScanning: Bool = false {
        didSet {
            print("[DeviceManager] isScanning updated: \(isScanning)")
            NSLog("[DeviceManager] isScanning updated: %@", isScanning ? "YES" : "NO")
        }
    }
    @Published public var showConnectionDialog: Bool = false
    
    public init() {
        print("[DeviceManager] Initializing...")
        NSLog("[DeviceManager] About to call loraCommsInit()")
        
        if let testPtr = loraCommsTest() {
            let testString = String(cString: testPtr)
            loraCommsFreeString(testPtr)
            NSLog("[DeviceManager] loraCommsTest() returned: %@", testString)
        } else {
            NSLog("[DeviceManager] loraCommsTest() returned NULL")
        }
        
        self.manager = loraCommsInit()
        NSLog("[DeviceManager] loraCommsInit() returned: %@", String(describing: self.manager))
        if self.manager == nil {
            NSLog("[DeviceManager] FAILED to initialize Rust core library")
        } else {
            NSLog("[DeviceManager] Successfully initialized Rust core library at %@", String(describing: self.manager))
        }
        
        // No need to forward changes - direct @Published properties handle this
    }
    
    deinit {
        if let manager = manager {
            loraCommsCleanup(manager)
        }
    }
    
    // MARK: - Device Scanning
    
    public func scanDevices() async {
        NSLog("[DeviceManager] scanDevices() called")
        print("[DeviceManager] scanDevices() called")
        
        guard let manager = manager else {
            print("Manager not initialized")
            NSLog("[DeviceManager] Manager not initialized")
            return
        }
        
        NSLog("[DeviceManager] Manager is initialized, proceeding with scan")
        
        await MainActor.run {
            isScanning = true
        }
        
        // Check cache first if Redis is connected
        if redisCache.isConnected {
            NSLog("[DeviceManager] Checking Redis cache for devices")
            if await redisCache.isScanCacheValid() {
                NSLog("[DeviceManager] Using cached devices")
                if let cachedDevices = await redisCache.getCachedAvailableDevices() {
                    await MainActor.run {
                        print("[DeviceManager] Loaded \(cachedDevices.count) devices from cache")
                        availableDevices = cachedDevices
                        isScanning = false
                    }
                    return
                }
            }
        }
        
        // Perform scanning on background queue
        do {
            let devices = try await withUnsafeThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    NSLog("[Swift] Starting device scan...")
                    // Add delay to ensure UI has time to show scanning state
                    NSLog("[Swift] About to sleep for 200ms to allow UI update")
                    Thread.sleep(forTimeInterval: 0.2) // 200ms delay
                    NSLog("[Swift] Sleep completed, calling Rust scan function")
                    let deviceArray = loraCommsScanDevices(manager)
                    NSLog("[Swift] Got device array with count: %d", deviceArray.count)
                    
                    var devices: [DeviceInfo] = []
                    
                    if let devicePtr = deviceArray.devices {
                        for i in 0..<deviceArray.count {
                            let cDevice = devicePtr[i]
                            
                            let id = String(cString: cDevice.id)
                            let name = String(cString: cDevice.name)
                            let path = String(cString: cDevice.path)
                            let deviceType = DeviceType(rawValue: Int(cDevice.deviceType)) ?? .serial
                            let manufacturer = cDevice.manufacturer != nil ? String(cString: cDevice.manufacturer!) : nil
                            let vendorId = cDevice.vendorId != nil ? String(cString: cDevice.vendorId!) : nil
                            let productId = cDevice.productId != nil ? String(cString: cDevice.productId!) : nil
                            
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
                    }
                    
                    print("[Swift] Processed \(devices.count) devices")
                    loraCommsFreeDeviceArray(deviceArray)
                    continuation.resume(returning: devices)
                }
            }
            
            await MainActor.run {
                print("[Swift] Updating UI with \(devices.count) devices")
                print("[Swift] Current availableDevices count before update: \(availableDevices.count)")
                
                // Filter out duplicate devices based on normalized path (same physical device might appear multiple times)
                // On macOS, serial devices create both tty and cu entries for the same physical device
                var uniqueDevices: [DeviceInfo] = []
                var seenDeviceKeys: Set<String> = []
                
                print("[Swift] --- Device Deduplication Analysis ---")
                for (index, device) in devices.enumerated() {
                    print("[Swift] Device \(index): name=\"\(device.name)\", id=\"\(device.id)\", path=\"\(device.path)\"")
                }
                
                // Helper function to normalize device path for deduplication
                func normalizeDevicePath(_ path: String) -> String {
                    // Convert both /dev/tty.xxx and /dev/cu.xxx to the same key
                    if path.hasPrefix("/dev/tty.") {
                        return path.replacingOccurrences(of: "/dev/tty.", with: "/dev/serial.")
                    } else if path.hasPrefix("/dev/cu.") {
                        return path.replacingOccurrences(of: "/dev/cu.", with: "/dev/serial.")
                    }
                    return path
                }
                
                for device in devices {
                    let normalizedKey = normalizeDevicePath(device.path)
                    print("[Swift] Processing device: name=\"\(device.name)\", path=\"\(device.path)\", normalized=\"\(normalizedKey)\"")
                    
                    if !seenDeviceKeys.contains(normalizedKey) {
                        seenDeviceKeys.insert(normalizedKey)
                        // Prefer cu.* devices over tty.* devices for serial communication
                        if device.path.hasPrefix("/dev/cu.") || !devices.contains(where: { $0.path.hasPrefix("/dev/cu.") && normalizeDevicePath($0.path) == normalizedKey }) {
                            uniqueDevices.append(device)
                            print("[Swift] ✓ Added device: \(device.name) at path \(device.path)")
                        } else {
                            print("[Swift] ○ Skipping tty device (cu variant preferred): \(device.name) at path \(device.path)")
                        }
                    } else {
                        print("[Swift] ✗ Filtering duplicate device: \(device.name) at path \(device.path)")
                    }
                }
                print("[Swift] --- End Deduplication Analysis ---")
                
                availableDevices = uniqueDevices
                print("[Swift] Current availableDevices count after update: \(availableDevices.count) (filtered from \(devices.count))")
                for (index, device) in uniqueDevices.enumerated() {
                    print("[Swift] Device \(index): id=\(device.id), name=\(device.name), path=\(device.path), available=\(device.isAvailable)")
                }
                isScanning = false
            }
            
            // Cache the results if Redis is connected
            if redisCache.isConnected {
                NSLog("[DeviceManager] Caching \(devices.count) devices to Redis")
                await redisCache.cacheAvailableDevices(devices)
            }
        } catch {
            print("Error scanning devices: \(error)")
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    // MARK: - Device Connection
    
    public func connectDevice(_ deviceInfo: DeviceInfo) async -> Bool {
        guard let manager = manager else {
            print("Manager not initialized")
            return false
        }
        
        do {
            return try await withUnsafeThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = deviceInfo.path.withCString { pathPtr in
                        if let deviceIdPtr = loraCommsConnectDevice(manager, pathPtr, UInt32(deviceInfo.deviceType.rawValue)) {
                            let deviceId = String(cString: deviceIdPtr)
                            loraCommsFreeString(deviceIdPtr)
                            
                            DispatchQueue.main.async {
                                self.activeDeviceId = deviceId
                                
                                let connection = DeviceConnection(deviceInfo: deviceInfo)
                                connection.setConnected()
                                
                                self.connections.removeAll { $0.deviceInfo.id == deviceInfo.id }
                                self.connections.append(connection)
                                
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
        } catch {
            print("Error connecting device: \(error)")
            return false
        }
    }
    
    public func disconnectDevice(_ deviceInfo: DeviceInfo) {
        // Remove connection
        self.connections.removeAll { $0.deviceInfo.id == deviceInfo.id }
        
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
        
        do {
            return try await withUnsafeThrowingContinuation { continuation in
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
                            self.messages.append(message)
                            
                            // Cache messages if Redis is connected
                            if self.redisCache.isConnected {
                                Task {
                                    await self.redisCache.cacheMessages(self.messages, for: deviceId)
                                }
                            }
                        }
                    }
                    
                    continuation.resume(returning: success)
                }
            }
        } catch {
            print("Error sending message: \(error)")
            return false
        }
    }
    
    public func getNodes() async {
        guard let manager = manager,
              let deviceId = activeDeviceId else {
            return
        }
        
        do {
            let nodes = try await withUnsafeThrowingContinuation { continuation in
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
                self.nodes = nodes
            }
            
            // Cache nodes if Redis is connected
            if redisCache.isConnected {
                NSLog("[DeviceManager] Caching \(nodes.count) nodes to Redis")
                await redisCache.cacheNodes(nodes)
            }
        } catch {
            print("Error getting nodes: \(error)")
        }
    }
    
    // MARK: - Message Polling
    
    private func startMessagePolling() {
        stopMessagePolling()
        
        // Start a background task to continuously poll for incoming messages
        // from the connected LoRa device
        messageTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task {
                await self.pollForIncomingMessages()
            }
        }
    }
    
    private func stopMessagePolling() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    private func pollForIncomingMessages() async {
        guard let manager = manager,
              let activeDeviceId = activeDeviceId else {
            return
        }
        
        // In a real implementation, this would call into the Rust core library
        // to check for new messages from the LoRa device
        // For now, this is a placeholder that would interface with actual hardware
        
        // TODO: Implement actual message polling from Rust FFI
        // This could call something like:
        // let newMessages = loraCommsGetNewMessages(manager, activeDeviceId)
        // and then process those messages
        
        // Once we implement real LoRa communication, we would:
        // 1. Call the Rust FFI to get new messages
        // 2. Decode the messages using our protocol handler
        // 3. Update the UI on the main thread
    }
    
    // MARK: - Cache Management
    
    /// Get Redis cache connection status
    public var isCacheConnected: Bool {
        return redisCache.isConnected
    }
    
    /// Get cache statistics
    public func getCacheStats() async -> [String: Any] {
        return await redisCache.getCacheStats()
    }
    
    /// Clear all cached data
    public func clearCache() async {
        await redisCache.clearCache()
    }
    
    /// Load cached messages for the active device
    public func loadCachedMessages() async {
        guard let deviceId = activeDeviceId,
              redisCache.isConnected else { return }
        
        if let cachedMessages = await redisCache.getCachedMessages(for: deviceId) {
            await MainActor.run {
                self.messages = cachedMessages
                NSLog("[DeviceManager] Loaded \(cachedMessages.count) cached messages")
            }
        }
    }
    
    /// Load cached nodes
    public func loadCachedNodes() async {
        guard redisCache.isConnected else { return }
        
        if let cachedNodes = await redisCache.getCachedNodes() {
            await MainActor.run {
                self.nodes = cachedNodes
                NSLog("[DeviceManager] Loaded \(cachedNodes.count) cached nodes")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    public var activeConnection: DeviceConnection? {
        connections.first { $0.status.isConnected }
    }
    
    public var isConnected: Bool {
        return activeConnection != nil
    }
    
    public var connectedDevice: DeviceInfo? {
        return activeConnection?.deviceInfo
    }
}
