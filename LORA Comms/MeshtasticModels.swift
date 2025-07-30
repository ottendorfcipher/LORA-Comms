import Foundation
import SwiftUI

// MARK: - Device Profile Models

public struct DeviceProfile: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var callSign: String // Amateur radio call sign or identifier
    public var longName: String // Full descriptive name
    public var shortName: String // 4-character short name for display
    public var hwModel: String // Hardware model identifier
    public var role: DeviceRole
    public var region: LoRaRegion
    public var channelSettings: ChannelSettings
    public var position: Position?
    public var lastSeen: Date
    public var batteryLevel: Int? // Battery percentage 0-100
    public var voltage: Double? // Battery voltage
    public var isOnline: Bool
    public var publicKey: String? // For encrypted communications
    
    public init(
        id: String,
        name: String,
        callSign: String = "",
        longName: String = "",
        shortName: String = "",
        hwModel: String = "UNKNOWN",
        role: DeviceRole = .client,
        region: LoRaRegion = .us
    ) {
        self.id = id
        self.name = name
        self.callSign = callSign
        self.longName = longName.isEmpty ? name : longName
        self.shortName = shortName.isEmpty ? String(name.prefix(4)).uppercased() : shortName
        self.hwModel = hwModel
        self.role = role
        self.region = region
        self.channelSettings = ChannelSettings()
        self.position = nil
        self.lastSeen = Date()
        self.batteryLevel = nil
        self.voltage = nil
        self.isOnline = false
        self.publicKey = nil
    }
}

public enum DeviceRole: String, CaseIterable, Codable {
    case client = "CLIENT"
    case router = "ROUTER"
    case repeater = "REPEATER"
    case tracker = "TRACKER"
    case sensor = "SENSOR"
    case tak = "TAK"
    case clientMute = "CLIENT_MUTE"
    case routerClient = "ROUTER_CLIENT"
    
    public var description: String {
        switch self {
        case .client: return "Client"
        case .router: return "Router"
        case .repeater: return "Repeater"
        case .tracker: return "Tracker"
        case .sensor: return "Sensor"
        case .tak: return "TAK"
        case .clientMute: return "Client (Mute)"
        case .routerClient: return "Router Client"
        }
    }
    
    public var icon: String {
        switch self {
        case .client: return "person.fill"
        case .router: return "network"
        case .repeater: return "antenna.radiowaves.left.and.right"
        case .tracker: return "location.fill"
        case .sensor: return "sensor.fill"
        case .tak: return "shield.fill"
        case .clientMute: return "person.fill.questionmark"
        case .routerClient: return "person.2.fill"
        }
    }
}

public enum LoRaRegion: String, CaseIterable, Codable {
    case unset = "UNSET"
    case us = "US"
    case eu433 = "EU_433"
    case eu868 = "EU_868"
    case cn = "CN"
    case jp = "JP"
    case anz = "ANZ"
    case kr = "KR"
    case tw = "TW"
    case ru = "RU"
    case `in` = "IN"
    case nz865 = "NZ_865"
    case th = "TH"
    case lora24 = "LORA_24"
    case ua433 = "UA_433"
    case ua868 = "UA_868"
    case my433 = "MY_433"
    case my919 = "MY_919"
    case sg923 = "SG_923"
    
    public var description: String {
        return rawValue.replacingOccurrences(of: "_", with: " ")
    }
    
    public var frequencyRange: String {
        switch self {
        case .unset: return "Not Set"
        case .us: return "902-928 MHz"
        case .eu433: return "433 MHz"
        case .eu868: return "868 MHz"
        case .cn: return "470-510 MHz"
        case .jp: return "920-923 MHz"
        case .anz: return "915-928 MHz"
        case .kr: return "920-923 MHz"
        case .tw: return "920-925 MHz"
        case .ru: return "868-870 MHz"
        case .in: return "865-867 MHz"
        case .nz865: return "864-868 MHz"
        case .th: return "920-925 MHz"
        case .lora24: return "2.4 GHz"
        case .ua433: return "433 MHz"
        case .ua868: return "868 MHz"
        case .my433: return "433 MHz"
        case .my919: return "919-924 MHz"
        case .sg923: return "923-925 MHz"
        }
    }
}

// MARK: - Channel and Communication Settings

public struct ChannelSettings: Codable, Hashable {
    public var primaryChannel: Channel
    public var secondaryChannels: [Channel]
    public var maxHops: Int
    public var transmitPower: Int // dBm
    public var spreadingFactor: Int
    public var codingRate: Int
    public var bandwidth: Double // Hz
    
    public init() {
        self.primaryChannel = Channel.defaultPrimary()
        self.secondaryChannels = []
        self.maxHops = 3
        self.transmitPower = 20
        self.spreadingFactor = 12
        self.codingRate = 8
        self.bandwidth = 125000
    }
}

public struct Channel: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var psk: Data? // Pre-shared key for encryption
    public var uplinkEnabled: Bool
    public var downlinkEnabled: Bool
    public var index: Int
    public var role: ChannelRole
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        psk: Data? = nil,
        uplinkEnabled: Bool = true,
        downlinkEnabled: Bool = true,
        index: Int = 0,
        role: ChannelRole = .primary
    ) {
        self.id = id
        self.name = name
        self.psk = psk
        self.uplinkEnabled = uplinkEnabled
        self.downlinkEnabled = downlinkEnabled
        self.index = index
        self.role = role
    }
    
    public static func defaultPrimary() -> Channel {
        return Channel(
            name: "LongFast",
            index: 0,
            role: .primary
        )
    }
}

public enum ChannelRole: String, CaseIterable, Codable {
    case primary = "PRIMARY"
    case secondary = "SECONDARY"
    case disabled = "DISABLED"
    
    public var description: String {
        return rawValue.capitalized
    }
}

// MARK: - Position and Location

public struct Position: Codable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Int? // meters above sea level
    public var precision: Int? // precision in bits
    public var timestamp: Date
    
    public init(latitude: Double, longitude: Double, altitude: Int? = nil, precision: Int? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.precision = precision
        self.timestamp = Date()
    }
}

// MARK: - Chat Models

public struct ChatRoom: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var type: ChatType
    public var participants: Set<String> // Device profile IDs
    public var channelId: String? // For channel-specific chats
    public var isEncrypted: Bool
    public var createdAt: Date
    public var lastActivity: Date
    public var unreadCount: Int
    public var isArchived: Bool
    public var description: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        type: ChatType,
        participants: Set<String> = [],
        channelId: String? = nil,
        isEncrypted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.participants = participants
        self.channelId = channelId
        self.isEncrypted = isEncrypted
        self.createdAt = Date()
        self.lastActivity = Date()
        self.unreadCount = 0
        self.isArchived = false
        self.description = nil
    }
}

public enum ChatType: String, CaseIterable, Codable {
    case direct = "DIRECT" // 1-to-1 chat
    case broadcast = "BROADCAST" // 1-to-many broadcast
    case group = "GROUP" // Group chat with specific members
    case channel = "CHANNEL" // Channel-based public chat
    case emergency = "EMERGENCY" // Emergency broadcasts
    
    public var description: String {
        switch self {
        case .direct: return "Direct Message"
        case .broadcast: return "Broadcast"
        case .group: return "Group Chat"
        case .channel: return "Channel Chat"
        case .emergency: return "Emergency"
        }
    }
    
    public var icon: String {
        switch self {
        case .direct: return "person.2.fill"
        case .broadcast: return "antenna.radiowaves.left.and.right"
        case .group: return "person.3.fill"
        case .channel: return "number"
        case .emergency: return "exclamationmark.triangle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .direct: return .blue
        case .broadcast: return .orange
        case .group: return .green
        case .channel: return .purple
        case .emergency: return .red
        }
    }
}

// MARK: - Message Models

public struct MeshtasticMessage: Identifiable, Codable, Hashable {
    public let id: String
    public var fromId: String // Device profile ID
    public var toId: String? // Device profile ID (nil for broadcast)
    public var chatRoomId: String
    public var content: MessageContent
    public var timestamp: Date
    public var deliveryStatus: DeliveryStatus
    public var hopsRemaining: Int
    public var snr: Double? // Signal-to-noise ratio
    public var rssi: Int? // Received signal strength indicator
    public var channelId: String?
    public var isEncrypted: Bool
    public var priority: MessagePriority
    public var expiresAt: Date?
    public var encryptedPayload: String? // Base64 encoded encrypted content
    public var decryptionFailed: Bool = false // Flag to indicate decryption failure
    
    public init(
        id: String = UUID().uuidString,
        fromId: String,
        toId: String? = nil,
        chatRoomId: String,
        content: MessageContent,
        hopsRemaining: Int = 3,
        channelId: String? = nil,
        isEncrypted: Bool = false,
        priority: MessagePriority = .normal
    ) {
        self.id = id
        self.fromId = fromId
        self.toId = toId
        self.chatRoomId = chatRoomId
        self.content = content
        self.timestamp = Date()
        self.deliveryStatus = .sending
        self.hopsRemaining = hopsRemaining
        self.snr = nil
        self.rssi = nil
        self.channelId = channelId
        self.isEncrypted = isEncrypted
        self.priority = priority
        self.expiresAt = nil
    }
}

public enum MessageContent: Codable, Hashable {
    case text(String)
    case position(Position)
    case nodeInfo(DeviceProfile)
    case telemetry(TelemetryData)
    case waypoint(Waypoint)
    case adminMessage(AdminMessage)
    case routing(RoutingMessage)
    
    public var displayText: String {
        switch self {
        case .text(let text):
            return text
        case .position(let pos):
            return "📍 Location: \(pos.latitude), \(pos.longitude)"
        case .nodeInfo(let profile):
            return "ℹ️ Node info for \(profile.name)"
        case .telemetry(let data):
            return "📊 Telemetry: \(data.summary)"
        case .waypoint(let waypoint):
            return "🚩 Waypoint: \(waypoint.name)"
        case .adminMessage(let admin):
            return "⚙️ Admin: \(admin.type.rawValue)"
        case .routing(let routing):
            return "🔄 Routing: \(routing.type.rawValue)"
        }
    }
}

public enum DeliveryStatus: String, Codable {
    case sending = "SENDING"
    case sent = "SENT"
    case delivered = "DELIVERED"
    case acknowledged = "ACKNOWLEDGED"
    case failed = "FAILED"
    case expired = "EXPIRED"
    
    public var icon: String {
        switch self {
        case .sending: return "arrow.up.circle"
        case .sent: return "checkmark.circle"
        case .delivered: return "checkmark.circle.fill"
        case .acknowledged: return "checkmark.circle.fill"
        case .failed: return "xmark.circle"
        case .expired: return "clock.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .sending: return .blue
        case .sent: return .orange
        case .delivered: return .green
        case .acknowledged: return .green
        case .failed: return .red
        case .expired: return .gray
        }
    }
}

public enum MessagePriority: String, CaseIterable, Codable {
    case low = "LOW"
    case normal = "NORMAL"
    case high = "HIGH"
    case emergency = "EMERGENCY"
    
    public var numericValue: Int {
        switch self {
        case .low: return 1
        case .normal: return 5
        case .high: return 8
        case .emergency: return 10
        }
    }
}

// MARK: - Supporting Data Types

public struct TelemetryData: Codable, Hashable {
    public var batteryLevel: Int?
    public var voltage: Double?
    public var current: Double?
    public var temperature: Double?
    public var humidity: Double?
    public var pressure: Double?
    public var gasResistance: Double?
    public var timestamp: Date
    
    public var summary: String {
        var parts: [String] = []
        if let battery = batteryLevel {
            parts.append("🔋 \(battery)%")
        }
        if let temp = temperature {
            parts.append("🌡️ \(String(format: "%.1f", temp))°C")
        }
        if let hum = humidity {
            parts.append("💧 \(String(format: "%.1f", hum))%")
        }
        return parts.isEmpty ? "No data" : parts.joined(separator: " ")
    }
    
    public init() {
        self.timestamp = Date()
    }
}

public struct Waypoint: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var description: String?
    public var position: Position
    public var icon: String
    public var createdAt: Date
    
    public init(id: String = UUID().uuidString, name: String, position: Position, icon: String = "📍") {
        self.id = id
        self.name = name
        self.position = position
        self.icon = icon
        self.createdAt = Date()
    }
}

public struct AdminMessage: Codable, Hashable {
    public var type: AdminMessageType
    public var payload: Data?
    
    public enum AdminMessageType: String, Codable {
        case getChannel = "GET_CHANNEL"
        case setChannel = "SET_CHANNEL"
        case getConfig = "GET_CONFIG"
        case setConfig = "SET_CONFIG"
        case getModuleConfig = "GET_MODULE_CONFIG"
        case setModuleConfig = "SET_MODULE_CONFIG"
        case reboot = "REBOOT"
        case factoryReset = "FACTORY_RESET"
    }
}

public struct RoutingMessage: Codable, Hashable {
    public var type: RoutingMessageType
    public var requestId: UInt32?
    public var route: [String]? // Node IDs in route
    
    public enum RoutingMessageType: String, Codable {
        case routeRequest = "ROUTE_REQUEST"
        case routeReply = "ROUTE_REPLY"
        case routeError = "ROUTE_ERROR"
    }
}

// MARK: - Network and Discovery

public struct MeshNetwork: Identifiable, Codable {
    public let id: String
    public var name: String
    public var profiles: [DeviceProfile]
    public var topology: NetworkTopology
    public var lastUpdated: Date
    
    public init(id: String = UUID().uuidString, name: String = "Local Mesh") {
        self.id = id
        self.name = name
        self.profiles = []
        self.topology = NetworkTopology()
        self.lastUpdated = Date()
    }
}

public struct NetworkTopology: Codable {
    public var connections: [NetworkConnection]
    public var routes: [NetworkRoute]
    
    public init() {
        self.connections = []
        self.routes = []
    }
}

public struct NetworkConnection: Identifiable, Codable {
    public let id: String
    public var fromNodeId: String
    public var toNodeId: String
    public var signalStrength: Int? // RSSI
    public var signalQuality: Double? // SNR
    public var lastSeen: Date
    
    public init(fromNodeId: String, toNodeId: String) {
        self.id = "\(fromNodeId)-\(toNodeId)"
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.lastSeen = Date()
    }
}

public struct NetworkRoute: Identifiable, Codable {
    public let id: String
    public var destinationId: String
    public var nextHopId: String
    public var hopCount: Int
    public var metric: Int // Route quality metric
    public var lastUpdated: Date
    
    public init(destinationId: String, nextHopId: String, hopCount: Int = 1, metric: Int = 1) {
        self.id = "\(destinationId)-\(nextHopId)"
        self.destinationId = destinationId
        self.nextHopId = nextHopId
        self.hopCount = hopCount
        self.metric = metric
        self.lastUpdated = Date()
    }
}

// MARK: - Message Encryption Extension

extension MeshtasticMessage {
    /// Encrypts the message content and stores it in encryptedPayload
    public mutating func encrypt() {
        guard case .text(let textContent) = content else {
            // Only encrypt text messages for now
            return
        }
        
        do {
            let encryptedText = try CryptoManager.shared.encrypt(string: textContent)
            self.encryptedPayload = encryptedText
            self.isEncrypted = true
        } catch {
            print("Encryption failed: \(error)")
            self.isEncrypted = false
        }
    }
    
    /// Decrypts the encryptedPayload and updates the content
    public mutating func decrypt() {
        guard isEncrypted, let encryptedText = encryptedPayload else {
            return
        }
        
        do {
            let decryptedText = try CryptoManager.shared.decrypt(base64String: encryptedText)
            self.content = .text(decryptedText)
            self.decryptionFailed = false
        } catch {
            print("Decryption failed: \(error)")
            self.decryptionFailed = true
            self.content = .text("🔒 Message could not be decrypted")
        }
    }
    
    /// Creates an encrypted message from a text string
    public static func createEncryptedMessage(
        fromId: String,
        toId: String? = nil,
        chatRoomId: String,
        text: String,
        priority: MessagePriority = .normal
    ) -> MeshtasticMessage {
        var message = MeshtasticMessage(
            fromId: fromId,
            toId: toId,
            chatRoomId: chatRoomId,
            content: .text(text),
            priority: priority
        )
        message.encrypt()
        return message
    }
    
    /// Returns the display text with proper encryption indicators
    public var secureDisplayText: String {
        if isEncrypted {
            if decryptionFailed {
                return "🔓 " + content.displayText
            } else {
                return "🔒 " + content.displayText
            }
        } else {
            return content.displayText
        }
    }
}
