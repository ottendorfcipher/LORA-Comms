import Foundation
import Network

/// Redis caching layer for LORA Comms app
/// Provides caching for device information, scan results, and message history
public class RedisCache: ObservableObject {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "redis-cache", qos: .utility)
    
    @Published public var isConnected = false
    
    // Cache keys
    private enum CacheKey {
        static let availableDevices = "lora:devices:available"
        static let scanHistory = "lora:scan:history"
        static let messageHistory = "lora:messages:history"
        static let nodeList = "lora:nodes:list"
        static let lastScanTime = "lora:scan:last_time"
        
        static func deviceDetails(_ deviceId: String) -> String {
            return "lora:device:\(deviceId):details"
        }
        
        static func deviceMessages(_ deviceId: String) -> String {
            return "lora:device:\(deviceId):messages"
        }
    }
    
    public init(host: String = "127.0.0.1", port: UInt16 = 6379) {
        // Create connection to Redis server
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        setupConnection()
    }
    
    deinit {
        connection.cancel()
    }
    
    private func setupConnection() {
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    NSLog("[RedisCache] Connected to Redis server")
                case .failed(let error):
                    self?.isConnected = false
                    NSLog("[RedisCache] Connection failed: %@", error.localizedDescription)
                case .cancelled:
                    self?.isConnected = false
                    NSLog("[RedisCache] Connection cancelled")
                default:
                    self?.isConnected = false
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    // MARK: - Device Caching
    
    /// Cache the list of available devices
    public func cacheAvailableDevices(_ devices: [DeviceInfo]) async {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(devices),
              let jsonString = String(data: data, encoding: .utf8) else {
            NSLog("[RedisCache] Failed to encode devices for caching")
            return
        }
        
        await setString(key: CacheKey.availableDevices, value: jsonString, expiry: 300) // 5 minutes
        await setString(key: CacheKey.lastScanTime, value: String(Date().timeIntervalSince1970))
    }
    
    /// Retrieve cached available devices
    public func getCachedAvailableDevices() async -> [DeviceInfo]? {
        guard let jsonString = await getString(key: CacheKey.availableDevices) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8),
              let devices = try? decoder.decode([DeviceInfo].self, from: data) else {
            NSLog("[RedisCache] Failed to decode cached devices")
            return nil
        }
        
        return devices
    }
    
    /// Check if device scan cache is still valid
    public func isScanCacheValid(maxAge: TimeInterval = 300) async -> Bool {
        guard let lastScanString = await getString(key: CacheKey.lastScanTime),
              let lastScanTime = Double(lastScanString) else {
            return false
        }
        
        let timeSince = Date().timeIntervalSince1970 - lastScanTime
        return timeSince < maxAge
    }
    
    // MARK: - Message Caching
    
    /// Cache messages for a specific device
    public func cacheMessages(_ messages: [MeshMessage], for deviceId: String) async {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(messages),
              let jsonString = String(data: data, encoding: .utf8) else {
            NSLog("[RedisCache] Failed to encode messages for caching")
            return
        }
        
        await setString(key: CacheKey.deviceMessages(deviceId), value: jsonString, expiry: 3600) // 1 hour
    }
    
    /// Retrieve cached messages for a device
    public func getCachedMessages(for deviceId: String) async -> [MeshMessage]? {
        guard let jsonString = await getString(key: CacheKey.deviceMessages(deviceId)) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8),
              let messages = try? decoder.decode([MeshMessage].self, from: data) else {
            NSLog("[RedisCache] Failed to decode cached messages")
            return nil
        }
        
        return messages
    }
    
    // MARK: - Node Caching
    
    /// Cache mesh nodes list
    public func cacheNodes(_ nodes: [NodeInfo]) async {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(nodes),
              let jsonString = String(data: data, encoding: .utf8) else {
            NSLog("[RedisCache] Failed to encode nodes for caching")
            return
        }
        
        await setString(key: CacheKey.nodeList, value: jsonString, expiry: 1800) // 30 minutes
    }
    
    /// Retrieve cached nodes
    public func getCachedNodes() async -> [NodeInfo]? {
        guard let jsonString = await getString(key: CacheKey.nodeList) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8),
              let nodes = try? decoder.decode([NodeInfo].self, from: data) else {
            NSLog("[RedisCache] Failed to decode cached nodes")
            return nil
        }
        
        return nodes
    }
    
    // MARK: - Statistics
    
    /// Get cache statistics
    public func getCacheStats() async -> [String: Any] {
        var stats: [String: Any] = [:]
        
        stats["connected"] = isConnected
        stats["has_devices"] = await exists(key: CacheKey.availableDevices)
        stats["has_nodes"] = await exists(key: CacheKey.nodeList)
        
        if let lastScanString = await getString(key: CacheKey.lastScanTime),
           let lastScanTime = Double(lastScanString) {
            stats["last_scan_age"] = Date().timeIntervalSince1970 - lastScanTime
        }
        
        return stats
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data
    public func clearCache() async {
        await deleteKey(CacheKey.availableDevices)
        await deleteKey(CacheKey.scanHistory)
        await deleteKey(CacheKey.messageHistory)
        await deleteKey(CacheKey.nodeList)
        await deleteKey(CacheKey.lastScanTime)
        NSLog("[RedisCache] Cache cleared")
    }
    
    // MARK: - Low-level Redis Operations
    
    private func setString(key: String, value: String, expiry: TimeInterval? = nil) async {
        guard isConnected else { return }
        
        var command = "SET \(key) \"\(value)\""
        if let expiry = expiry {
            command += " EX \(Int(expiry))"
        }
        command += "\r\n"
        
        await sendCommand(command)
    }
    
    private func getString(key: String) async -> String? {
        guard isConnected else { return nil }
        
        let command = "GET \(key)\r\n"
        return await sendCommandWithResponse(command)
    }
    
    private func exists(key: String) async -> Bool {
        guard isConnected else { return false }
        
        let command = "EXISTS \(key)\r\n"
        if let response = await sendCommandWithResponse(command) {
            return response.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        }
        return false
    }
    
    private func deleteKey(_ key: String) async {
        guard isConnected else { return }
        
        let command = "DEL \(key)\r\n"
        await sendCommand(command)
    }
    
    private func sendCommand(_ command: String) async {
        guard let data = command.data(using: .utf8) else { return }
        
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    NSLog("[RedisCache] Send error: %@", error.localizedDescription)
                }
                continuation.resume()
            })
        }
    }
    
    private func sendCommandWithResponse(_ command: String) async -> String? {
        guard let data = command.data(using: .utf8) else { return nil }
        
        return await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    NSLog("[RedisCache] Send error: %@", error.localizedDescription)
                    continuation.resume(returning: nil)
                    return
                }
                
                // Receive response
                self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                    if let error = error {
                        NSLog("[RedisCache] Receive error: %@", error.localizedDescription)
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        // Parse Redis response format
                        let lines = response.components(separatedBy: "\r\n")
                        if lines.count > 1 && lines[0].hasPrefix("$") {
                            // Bulk string response
                            continuation.resume(returning: lines[1])
                        } else if lines[0].hasPrefix(":") {
                            // Integer response
                            let value = String(lines[0].dropFirst())
                            continuation.resume(returning: value)
                        } else if lines[0] == "$-1" {
                            // Null response
                            continuation.resume(returning: nil)
                        } else {
                            continuation.resume(returning: response)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            })
        }
    }
}
