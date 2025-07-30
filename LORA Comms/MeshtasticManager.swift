import Foundation
import SwiftUI

@MainActor
public class MeshtasticManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var deviceProfiles: [DeviceProfile] = []
    @Published public var chatRooms: [ChatRoom] = []
    @Published public var messages: [MeshtasticMessage] = []
    @Published public var currentProfile: DeviceProfile?
    @Published public var selectedChatRoom: ChatRoom?
    @Published public var meshNetwork: MeshNetwork = MeshNetwork()
    @Published public var isConnected: Bool = false
    @Published public var connectionStatus: String = "Disconnected"
    
    // MARK: - Private Properties
    private let deviceManager: DeviceManager
    private var messageTimer: Timer?
    
    public init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        loadSavedData()
        setupMessagePolling()
    }
    
    // MARK: - Profile Management
    
    public func createProfile(
        name: String,
        callSign: String = "",
        longName: String = "",
        shortName: String = "",
        role: DeviceRole = .client,
        region: LoRaRegion = .us
    ) -> DeviceProfile {
        let profile = DeviceProfile(
            id: UUID().uuidString,
            name: name,
            callSign: callSign,
            longName: longName,
            shortName: shortName,
            role: role,
            region: region
        )
        
        deviceProfiles.append(profile)
        saveData()
        return profile
    }
    
    public func updateProfile(_ profile: DeviceProfile) {
        if let index = deviceProfiles.firstIndex(where: { $0.id == profile.id }) {
            deviceProfiles[index] = profile
            saveData()
        }
    }
    
    public func deleteProfile(_ profile: DeviceProfile) {
        deviceProfiles.removeAll { $0.id == profile.id }
        if currentProfile?.id == profile.id {
            currentProfile = nil
        }
        saveData()
    }
    
    public func setCurrentProfile(_ profile: DeviceProfile) {
        currentProfile = profile
        connectionStatus = "Connected as \(profile.name)"
        isConnected = true
        saveData()
    }
    
    // MARK: - Chat Room Management
    
    public func createDirectChat(with participantId: String) -> ChatRoom {
        guard let currentProfile = currentProfile else {
            fatalError("No current profile selected")
        }
        
        // Check if direct chat already exists
        if let existingChat = chatRooms.first(where: { 
            $0.type == .direct && 
            $0.participants.contains(currentProfile.id) && 
            $0.participants.contains(participantId) 
        }) {
            return existingChat
        }
        
        let participant = deviceProfiles.first { $0.id == participantId }
        let chatName = participant?.name ?? "Direct Chat"
        
        let chatRoom = ChatRoom(
            name: chatName,
            type: .direct,
            participants: [currentProfile.id, participantId]
        )
        
        chatRooms.append(chatRoom)
        saveData()
        return chatRoom
    }
    
    public func createBroadcastChat(name: String) -> ChatRoom {
        guard let currentProfile = currentProfile else {
            fatalError("No current profile selected")
        }
        
        let chatRoom = ChatRoom(
            name: name,
            type: .broadcast,
            participants: [currentProfile.id]
        )
        
        chatRooms.append(chatRoom)
        saveData()
        return chatRoom
    }
    
    public func createGroupChat(name: String, participants: Set<String>) -> ChatRoom {
        guard let currentProfile = currentProfile else {
            fatalError("No current profile selected")
        }
        
        var allParticipants = participants
        allParticipants.insert(currentProfile.id)
        
        let chatRoom = ChatRoom(
            name: name,
            type: .group,
            participants: allParticipants
        )
        
        chatRooms.append(chatRoom)
        saveData()
        return chatRoom
    }
    
    public func createChannelChat(name: String, channelId: String) -> ChatRoom {
        let chatRoom = ChatRoom(
            name: name,
            type: .channel,
            channelId: channelId
        )
        
        chatRooms.append(chatRoom)
        saveData()
        return chatRoom
    }
    
    public func deleteChatRoom(_ chatRoom: ChatRoom) {
        chatRooms.removeAll { $0.id == chatRoom.id }
        messages.removeAll { $0.chatRoomId == chatRoom.id }
        if selectedChatRoom?.id == chatRoom.id {
            selectedChatRoom = nil
        }
        saveData()
    }
    
    // MARK: - Message Management
    
    public func sendMessage(
        to chatRoom: ChatRoom,
        content: MessageContent,
        priority: MessagePriority = .normal
    ) async {
        guard let currentProfile = currentProfile else {
            print("No current profile selected")
            return
        }
        
        let toId: String? = switch chatRoom.type {
        case .direct:
            chatRoom.participants.first { $0 != currentProfile.id }
        case .broadcast, .group, .channel, .emergency:
            nil // Broadcast messages
        }
        
        let message = MeshtasticMessage(
            fromId: currentProfile.id,
            toId: toId,
            chatRoomId: chatRoom.id,
            content: content,
            channelId: chatRoom.channelId,
            priority: priority
        )
        
        messages.append(message)
        
        // Update chat room activity
        updateChatRoomActivity(chatRoom.id)
        
        // Send through device manager
        await sendMessageThroughDevice(message)
        
        saveData()
    }
    
    public func sendMessage(_ message: MeshtasticMessage) async {
        // Decrypt the message if it's encrypted before displaying
        var processedMessage = message
        if message.isEncrypted {
            processedMessage.decrypt()
        }
        
        messages.append(processedMessage)
        
        // Update chat room activity
        updateChatRoomActivity(message.chatRoomId)
        
        // Send through device manager
        await sendMessageThroughDevice(message)
        
        saveData()
    }
    
    private func sendMessageThroughDevice(_ message: MeshtasticMessage) async {
        // This would interface with your existing DeviceManager
        // For now, we'll simulate the message sending
        print("Sending message: \(message.content.displayText)")
        
        // Simulate delivery status updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMessageStatus(message.id, status: .sent)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateMessageStatus(message.id, status: .delivered)
        }
    }
    
    public func updateMessageStatus(_ messageId: String, status: DeliveryStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].deliveryStatus = status
            saveData()
        }
    }
    
    public func receiveMessage(_ message: MeshtasticMessage) {
        var processedMessage = message
        if message.isEncrypted {
            processedMessage.decrypt()
        }
        
        messages.append(processedMessage)
        updateChatRoomActivity(message.chatRoomId)
        
        // Update unread count if chat room is not selected
        if selectedChatRoom?.id != message.chatRoomId {
            if let index = chatRooms.firstIndex(where: { $0.id == message.chatRoomId }) {
                chatRooms[index].unreadCount += 1
            }
        }
        
        saveData()
    }
    
    // MARK: - Utility Functions
    
    public func getMessagesForChatRoom(_ chatRoomId: String) -> [MeshtasticMessage] {
        return messages
            .filter { $0.chatRoomId == chatRoomId }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    public func markChatRoomAsRead(_ chatRoomId: String) {
        if let index = chatRooms.firstIndex(where: { $0.id == chatRoomId }) {
            chatRooms[index].unreadCount = 0
            saveData()
        }
    }
    
    private func updateChatRoomActivity(_ chatRoomId: String) {
        if let index = chatRooms.firstIndex(where: { $0.id == chatRoomId }) {
            chatRooms[index].lastActivity = Date()
        }
    }
    
    public func getAvailableProfiles(excluding profileId: String? = nil) -> [DeviceProfile] {
        return deviceProfiles.filter { profile in
            if let excludeId = profileId {
                return profile.id != excludeId && profile.isOnline
            }
            return profile.isOnline
        }
    }
    
    public func updateProfileFromNodeInfo(_ nodeInfo: NodeInfo) {
        // Convert NodeInfo to DeviceProfile or update existing profile
        if let existingProfile = deviceProfiles.first(where: { $0.id == nodeInfo.id }) {
            var updatedProfile = existingProfile
            updatedProfile.lastSeen = Date()
            updatedProfile.isOnline = nodeInfo.isOnline
            // NodeInfo doesn't have batteryLevel property
            // if let batteryLevel = nodeInfo.batteryLevel {
            //     updatedProfile.batteryLevel = batteryLevel
            // }
            updateProfile(updatedProfile)
        } else {
            // Create new profile from node info
            let newProfile = DeviceProfile(
                id: nodeInfo.id,
                name: nodeInfo.name,
                longName: nodeInfo.name,
                shortName: nodeInfo.shortName
            )
            deviceProfiles.append(newProfile)
        }
        saveData()
    }
    
    // MARK: - Network Discovery
    
    public func discoverNearbyNodes() async {
        // This would interface with the device manager to discover nearby nodes
        print("Discovering nearby Meshtastic nodes...")
        
        // Simulate discovery
        await deviceManager.scanDevices()
        
        // Process discovered nodes and create/update profiles
        for nodeInfo in deviceManager.nodes {
            updateProfileFromNodeInfo(nodeInfo)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveData() {
        Task {
            await saveProfiles()
            await saveChatRooms()
            await saveMessages()
        }
    }
    
    private func loadSavedData() {
        Task {
            await loadProfiles()
            await loadChatRooms()
            await loadMessages()
        }
    }
    
    private func saveProfiles() async {
        if let data = try? JSONEncoder().encode(deviceProfiles) {
            UserDefaults.standard.set(data, forKey: "MeshtasticProfiles")
        }
    }
    
    private func loadProfiles() async {
        if let data = UserDefaults.standard.data(forKey: "MeshtasticProfiles"),
           let profiles = try? JSONDecoder().decode([DeviceProfile].self, from: data) {
            await MainActor.run {
                self.deviceProfiles = profiles
            }
        }
    }
    
    private func saveChatRooms() async {
        if let data = try? JSONEncoder().encode(chatRooms) {
            UserDefaults.standard.set(data, forKey: "MeshtasticChatRooms")
        }
    }
    
    private func loadChatRooms() async {
        if let data = UserDefaults.standard.data(forKey: "MeshtasticChatRooms"),
           let rooms = try? JSONDecoder().decode([ChatRoom].self, from: data) {
            await MainActor.run {
                self.chatRooms = rooms
            }
        }
    }
    
    private func saveMessages() async {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "MeshtasticMessages")
        }
    }
    
    private func loadMessages() async {
        if let data = UserDefaults.standard.data(forKey: "MeshtasticMessages"),
           let msgs = try? JSONDecoder().decode([MeshtasticMessage].self, from: data) {
            await MainActor.run {
                self.messages = msgs
            }
        }
    }
    
    // MARK: - Message Polling
    
    private func setupMessagePolling() {
        messageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                await self.pollForNewMessages()
            }
        }
    }
    
    private func pollForNewMessages() async {
        // This would poll the device manager for new messages
        // For now, we'll just update online status of profiles
        for i in 0..<deviceProfiles.count {
            let timeSinceLastSeen = Date().timeIntervalSince(deviceProfiles[i].lastSeen)
            deviceProfiles[i].isOnline = timeSinceLastSeen < 300 // 5 minutes
        }
    }
    
    deinit {
        messageTimer?.invalidate()
    }
}
