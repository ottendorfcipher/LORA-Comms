import SwiftUI

// MARK: - Profile Creation View

struct ProfileCreationView: View {
    @ObservedObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    @State private var profileName: String = ""
    @State private var callSign: String = ""
    @State private var longName: String = ""
    @State private var shortName: String = ""
    @State private var selectedRole: DeviceRole = .client
    @State private var selectedRegion: LoRaRegion = .us
    @State private var transmitPower: Double = 20.0
    @State private var maxHops: Double = 3.0
    @State private var showingAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Call Sign (optional)", text: $callSign)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                    
                    TextField("Long Name (optional)", text: $longName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Short Name (4 chars)", text: $shortName)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                        .onChange(of: shortName) { _, newValue in
                            if newValue.count > 4 {
                                shortName = String(newValue.prefix(4))
                            }
                        }
                }
                
                Section("Device Configuration") {
                    Picker("Device Role", selection: $selectedRole) {
                        ForEach(DeviceRole.allCases, id: \.self) { role in
                            Label(role.description, systemImage: role.icon)
                                .tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("LoRa Region", selection: $selectedRegion) {
                        ForEach(LoRaRegion.allCases, id: \.self) { region in
                            VStack(alignment: .leading) {
                                Text(region.description)
                                Text(region.frequencyRange)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Advanced Settings") {
                    DisclosureGroup("Radio Configuration", isExpanded: $showingAdvancedSettings) {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Transmit Power: \(Int(transmitPower)) dBm")
                                    .font(.caption)
                                Slider(value: $transmitPower, in: 1...30, step: 1)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max Hops: \(Int(maxHops))")
                                    .font(.caption)
                                Slider(value: $maxHops, in: 1...7, step: 1)
                            }
                        }
                        .padding(.top)
                    }
                }
                
                Section {
                    Button("Create Profile") {
                        createProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profileName.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("New Profile")
            // .navigationBarTitleDisplayMode(.inline) // Not available on macOS
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createProfile() {
        let profile = meshtasticManager.createProfile(
            name: profileName,
            callSign: callSign,
            longName: longName.isEmpty ? profileName : longName,
            shortName: shortName.isEmpty ? String(profileName.prefix(4)).uppercased() : shortName,
            role: selectedRole,
            region: selectedRegion
        )
        
        // Set as current profile if it's the first one
        if meshtasticManager.deviceProfiles.count == 1 {
            meshtasticManager.setCurrentProfile(profile)
        }
        
        dismiss()
    }
}

// MARK: - Chat Creation View

struct ChatCreationView: View {
    @ObservedObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    @State private var chatName: String = ""
    @State private var selectedChatType: ChatType = .direct
    @State private var selectedParticipants: Set<String> = []
    @State private var isEncrypted: Bool = false
    @State private var selectedChannel: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Chat Information") {
                    TextField("Chat Name", text: $chatName)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Chat Type", selection: $selectedChatType) {
                        ForEach([ChatType.direct, .broadcast, .group, .channel], id: \.self) { type in
                            Label(type.description, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedChatType != .broadcast {
                        Toggle("Encrypted", isOn: $isEncrypted)
                    }
                }
                
                if selectedChatType == .direct || selectedChatType == .group {
                    participantSelectionSection
                }
                
                if selectedChatType == .channel {
                    channelSelectionSection
                }
                
                Section {
                    Button("Create Chat") {
                        createChat()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateChat)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("New Chat")
            // .navigationBarTitleDisplayMode(.inline) // Not available on macOS
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var participantSelectionSection: some View {
        Section("Participants") {
            ForEach(availableProfiles, id: \.id) { profile in
                HStack {
                    Image(systemName: profile.role.icon)
                        .foregroundColor(profile.isOnline ? .green : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        Text(profile.role.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if selectedParticipants.contains(profile.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleParticipant(profile.id)
                }
            }
        }
    }
    
    private var channelSelectionSection: some View {
        Section("Channel") {
            TextField("Channel ID", text: $selectedChannel)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var availableProfiles: [DeviceProfile] {
        return meshtasticManager.getAvailableProfiles(excluding: meshtasticManager.currentProfile?.id)
    }
    
    private var canCreateChat: Bool {
        guard !chatName.isEmpty else { return false }
        
        switch selectedChatType {
        case .direct:
            return selectedParticipants.count == 1
        case .broadcast:
            return true
        case .group:
            return selectedParticipants.count >= 2
        case .channel:
            return !selectedChannel.isEmpty
        case .emergency:
            return true
        }
    }
    
    private func toggleParticipant(_ participantId: String) {
        if selectedChatType == .direct {
            // Direct chat can only have one participant
            selectedParticipants = [participantId]
        } else {
            // Group chat can have multiple participants
            if selectedParticipants.contains(participantId) {
                selectedParticipants.remove(participantId)
            } else {
                selectedParticipants.insert(participantId)
            }
        }
    }
    
    private func createChat() {
        let chatRoom: ChatRoom
        
        switch selectedChatType {
        case .direct:
            if let participantId = selectedParticipants.first {
                chatRoom = meshtasticManager.createDirectChat(with: participantId)
            } else {
                return
            }
            
        case .broadcast:
            chatRoom = meshtasticManager.createBroadcastChat(name: chatName)
            
        case .group:
            chatRoom = meshtasticManager.createGroupChat(name: chatName, participants: selectedParticipants)
            
        case .channel:
            chatRoom = meshtasticManager.createChannelChat(name: chatName, channelId: selectedChannel)
            
        case .emergency:
            chatRoom = meshtasticManager.createBroadcastChat(name: chatName)
        }
        
        // Set encryption if requested
        if isEncrypted {
            // This would set up encryption for the chat room
            // For now, just mark it as encrypted
            var updatedChatRoom = chatRoom
            updatedChatRoom.isEncrypted = true
            // Update the chat room in the manager
        }
        
        meshtasticManager.selectedChatRoom = chatRoom
        dismiss()
    }
}

// MARK: - Network Topology View

struct NetworkTopologyView: View {
    @ObservedObject var meshtasticManager: MeshtasticManager
    @State private var selectedNode: DeviceProfile?
    @State private var showingNodeDetails = false
    
    var body: some View {
        VStack {
            if meshtasticManager.deviceProfiles.isEmpty {
                ContentUnavailableView(
                    "No Network Nodes",
                    systemImage: "network.slash",
                    description: Text("Discover nearby Meshtastic nodes to see the network topology")
                )
            } else {
                List {
                    Section("Network Overview") {
                        networkStatsView
                    }
                    
                    Section("Connected Nodes") {
                        ForEach(onlineNodes, id: \.id) { node in
                            NetworkNodeRowView(
                                node: node,
                                isCurrentNode: node.id == meshtasticManager.currentProfile?.id,
                                onTap: {
                                    selectedNode = node
                                    showingNodeDetails = true
                                }
                            )
                        }
                    }
                    
                    if !offlineNodes.isEmpty {
                        Section("Offline Nodes") {
                            ForEach(offlineNodes, id: \.id) { node in
                                NetworkNodeRowView(
                                    node: node,
                                    isCurrentNode: false,
                                    onTap: {
                                        selectedNode = node
                                        showingNodeDetails = true
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .refreshable {
                    await meshtasticManager.discoverNearbyNodes()
                }
            }
        }
        .sheet(isPresented: $showingNodeDetails) {
            if let selectedNode = selectedNode {
                NodeDetailView(node: selectedNode, meshtasticManager: meshtasticManager)
            }
        }
    }
    
    private var networkStatsView: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(onlineNodes.count)", systemImage: "circle.fill")
                    .foregroundColor(.green)
                Text("Online")
                
                Spacer()
                
                Label("\(offlineNodes.count)", systemImage: "circle")
                    .foregroundColor(.gray)
                Text("Offline")
            }
            
            HStack {
                Label("\(totalChatRooms)", systemImage: "message")
                Text("Active Chats")
                
                Spacer()
                
                Label("\(totalMessages)", systemImage: "envelope")
                Text("Messages")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var onlineNodes: [DeviceProfile] {
        meshtasticManager.deviceProfiles.filter { $0.isOnline }
    }
    
    private var offlineNodes: [DeviceProfile] {
        meshtasticManager.deviceProfiles.filter { !$0.isOnline }
    }
    
    private var totalChatRooms: Int {
        meshtasticManager.chatRooms.count
    }
    
    private var totalMessages: Int {
        meshtasticManager.messages.count
    }
}

// MARK: - Network Node Row View

struct NetworkNodeRowView: View {
    let node: DeviceProfile
    let isCurrentNode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Node Icon
            Image(systemName: node.role.icon)
                .font(.title3)
                .foregroundColor(nodeColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.name)
                        .font(.headline)
                        .foregroundColor(isCurrentNode ? .accentColor : .primary)
                    
                    if isCurrentNode {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(node.role.description) • \(node.region.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !node.callSign.isEmpty {
                    Text(node.callSign)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Online status
                HStack(spacing: 4) {
                    Circle()
                        .fill(node.isOnline ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(node.isOnline ? "Online" : "Offline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Battery level
                if let batteryLevel = node.batteryLevel {
                    HStack(spacing: 2) {
                        Image(systemName: "battery.100")
                            .font(.caption2)
                        Text("\(batteryLevel)%")
                            .font(.caption2)
                    }
                    .foregroundColor(batteryLevel > 20 ? .green : .red)
                }
                
                // Last seen
                    Text(RelativeDateTimeFormatter().localizedString(for: node.lastSeen, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var nodeColor: Color {
        if isCurrentNode {
            return .accentColor
        } else if node.isOnline {
            return .green
        } else {
            return .gray
        }
    }
}

// MARK: - Node Detail View

struct NodeDetailView: View {
    let node: DeviceProfile
    @ObservedObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Node Information") {
                    DetailRowView(title: "Name", value: node.name)
                    DetailRowView(title: "Long Name", value: node.longName)
                    DetailRowView(title: "Short Name", value: node.shortName)
                    if !node.callSign.isEmpty {
                        DetailRowView(title: "Call Sign", value: node.callSign)
                    }
                    DetailRowView(title: "Hardware Model", value: node.hwModel)
                }
                
                Section("Configuration") {
                    DetailRowView(title: "Role", value: node.role.description)
                    DetailRowView(title: "Region", value: "\(node.region.description) (\(node.region.frequencyRange))")
                    DetailRowView(title: "Max Hops", value: "\(node.channelSettings.maxHops)")
                    DetailRowView(title: "Transmit Power", value: "\(node.channelSettings.transmitPower) dBm")
                }
                
                Section("Status") {
                    HStack {
                        Text("Online Status")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(node.isOnline ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(node.isOnline ? "Online" : "Offline")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    DetailRowView(title: "Last Seen", value: DateFormatter.medium.string(from: node.lastSeen))
                    
                    if let batteryLevel = node.batteryLevel {
                        HStack {
                            Text("Battery Level")
                            Spacer()
                            HStack {
                                Image(systemName: "battery.100")
                                    .foregroundColor(batteryLevel > 20 ? .green : .red)
                                Text("\(batteryLevel)%")
                                    .foregroundColor(batteryLevel > 20 ? .green : .red)
                            }
                        }
                    }
                    
                    if let voltage = node.voltage {
                        DetailRowView(title: "Voltage", value: String(format: "%.2f V", voltage))
                    }
                }
                
                if let position = node.position {
                    Section("Location") {
                        DetailRowView(title: "Latitude", value: String(format: "%.6f", position.latitude))
                        DetailRowView(title: "Longitude", value: String(format: "%.6f", position.longitude))
                        if let altitude = position.altitude {
                            DetailRowView(title: "Altitude", value: "\(altitude) m")
                        }
                        DetailRowView(title: "Updated", value: DateFormatter.medium.string(from: position.timestamp))
                    }
                }
                
                Section("Actions") {
                    Button("Start Direct Chat") {
                        let chatRoom = meshtasticManager.createDirectChat(with: node.id)
                        meshtasticManager.selectedChatRoom = chatRoom
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    if node.id != meshtasticManager.currentProfile?.id {
                        Button("Set as Current Profile") {
                            meshtasticManager.setCurrentProfile(node)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle(node.name)
            // .navigationBarTitleDisplayMode(.inline) // Not available on macOS
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row View

struct DetailRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview("Profile Creation") {
    ProfileCreationView(meshtasticManager: MeshtasticManager(deviceManager: DeviceManager()))
}

#Preview("Chat Creation") {
    let manager = MeshtasticManager(deviceManager: DeviceManager())
    let profile1 = DeviceProfile(id: "1", name: "Test User 1")
    let profile2 = DeviceProfile(id: "2", name: "Test User 2")
    manager.deviceProfiles = [profile1, profile2]
    manager.currentProfile = profile1
    
    return ChatCreationView(meshtasticManager: manager)
}

#Preview("Network Topology") {
    let manager = MeshtasticManager(deviceManager: DeviceManager())
    return Group {
        let _ = {
            var profile1 = DeviceProfile(id: "1", name: "Base Station", role: .router)
            var profile2 = DeviceProfile(id: "2", name: "Mobile Unit", role: .client)
            profile1.isOnline = true
            profile1.batteryLevel = 85
            profile2.isOnline = false
            profile2.batteryLevel = 42
            manager.deviceProfiles = [profile1, profile2]
            manager.currentProfile = profile1
        }()
        
        NetworkTopologyView(meshtasticManager: manager)
    }
}
