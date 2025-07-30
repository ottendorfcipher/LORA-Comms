import Foundation

// MARK: - Device Models

public enum DeviceType: Int, CaseIterable, Identifiable {
    case serial = 0
    case bluetooth = 1
    case tcp = 2
    
    public var id: Int { rawValue }
    
    public var displayName: String {
        switch self {
        case .serial: return "Serial/USB"
        case .bluetooth: return "Bluetooth"
        case .tcp: return "Network/TCP"
        }
    }
    
    public var iconName: String {
        switch self {
        case .serial: return "cable.connector"
        case .bluetooth: return "bluetooth"
        case .tcp: return "network"
        }
    }
}

public struct DeviceInfo: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let deviceType: DeviceType
    public let manufacturer: String?
    public let vendorId: String?
    public let productId: String?
    public let isAvailable: Bool
    
    public init(
        id: String,
        name: String,
        path: String,
        deviceType: DeviceType,
        manufacturer: String? = nil,
        vendorId: String? = nil,
        productId: String? = nil,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.deviceType = deviceType
        self.manufacturer = manufacturer
        self.vendorId = vendorId
        self.productId = productId
        self.isAvailable = isAvailable
    }
}

// MARK: - Connection Models

public enum ConnectionStatus: Codable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    public var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

public struct DeviceConnection: Identifiable, ObservableObject {
    public let id = UUID()
    public let deviceInfo: DeviceInfo
    @Published public var status: ConnectionStatus = .disconnected
    @Published public var connectedAt: Date? = nil
    @Published public var lastActivity: Date? = nil
    
    public init(deviceInfo: DeviceInfo) {
        self.deviceInfo = deviceInfo
    }
    
    public mutating func setConnected() {
        self.status = .connected
        self.connectedAt = Date()
        self.lastActivity = Date()
    }
    
    public mutating func setDisconnected() {
        self.status = .disconnected
        self.connectedAt = nil
    }
    
    public mutating func setError(_ error: String) {
        self.status = .error(error)
    }
    
    public mutating func updateActivity() {
        self.lastActivity = Date()
    }
}

// MARK: - Message Models

public struct MeshMessage: Identifiable, Codable, Hashable {
    public let id: String
    public let text: String
    public let sender: String
    public let destination: String?
    public let timestamp: Date
    public let isFromMe: Bool
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        sender: String,
        destination: String? = nil,
        timestamp: Date = Date(),
        isFromMe: Bool = false
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.destination = destination
        self.timestamp = timestamp
        self.isFromMe = isFromMe
    }
    
    public static func outgoing(text: String, destination: String? = nil) -> MeshMessage {
        return MeshMessage(
            text: text,
            sender: "Me",
            destination: destination,
            isFromMe: true
        )
    }
}

// MARK: - Node Models

public struct NodeInfo: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let shortName: String
    public let isOnline: Bool
    
    public init(
        id: String,
        name: String,
        shortName: String,
        isOnline: Bool = false
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.isOnline = isOnline
    }
    
    public static let broadcast = NodeInfo(
        id: "broadcast",
        name: "All Nodes",
        shortName: "ALL",
        isOnline: true
    )
}

// MARK: - App State

public class AppState: ObservableObject {
    @Published public var availableDevices: [DeviceInfo] = []
    @Published public var connections: [DeviceConnection] = []
    @Published public var messages: [MeshMessage] = []
    @Published public var nodes: [NodeInfo] = [NodeInfo.broadcast]
    @Published public var selectedNodeId: String = "broadcast"
    @Published public var isScanning: Bool = false
    @Published public var showConnectionDialog: Bool = false
    
    public init() {}
    
    public var activeConnection: DeviceConnection? {
        connections.first { $0.status.isConnected }
    }
    
    public var selectedNode: NodeInfo? {
        nodes.first { $0.id == selectedNodeId }
    }
}
