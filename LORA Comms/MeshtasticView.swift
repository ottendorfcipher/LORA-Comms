import SwiftUI

struct MeshtasticView: View {
    @StateObject private var meshtasticManager: MeshtasticManager
    @State private var selectedTab: MeshtasticTab = .chats
    @State private var showingProfileCreation = false
    @State private var showingChatCreation = false
    
    init(deviceManager: DeviceManager) {
        self._meshtasticManager = StateObject(wrappedValue: MeshtasticManager(deviceManager: deviceManager))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Current Profile Section
                currentProfileSection
                
                Divider()
                
                // Tab Navigation
                tabNavigationSection
                
                Divider()
                
                // Main Content
                switch selectedTab {
                case .chats:
                    chatListSection
                case .profiles:
                    profileListSection
                case .network:
                    networkSection
                }
            }
            .navigationTitle("Meshtastic")
        } detail: {
            // Detail View
            if meshtasticManager.selectedChatRoom != nil {
                ChatDetailView(
                    meshtasticManager: meshtasticManager
                )
            } else {
                ContentUnavailableView(
                    "Select a Chat",
                    systemImage: "message",
                    description: Text("Choose a chat room to start messaging")
                )
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            ProfileCreationView(meshtasticManager: meshtasticManager)
        }
        .sheet(isPresented: $showingChatCreation) {
            ChatCreationView(meshtasticManager: meshtasticManager)
        }
    }
    
    // MARK: - Current Profile Section
    
    private var currentProfileSection: some View {
        VStack(spacing: 8) {
            if let currentProfile = meshtasticManager.currentProfile {
                HStack {
                    Image(systemName: currentProfile.role.icon)
                        .font(.title2)
                        .foregroundColor(currentProfile.isOnline ? .green : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentProfile.name)
                            .font(.headline)
                        Text(meshtasticManager.connectionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let batteryLevel = currentProfile.batteryLevel {
                        Label("\(batteryLevel)%", systemImage: "battery.100")
                            .font(.caption)
                            .foregroundColor(batteryLevel > 20 ? .green : .red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            } else {
                Button("Select Profile") {
                    selectedTab = .profiles
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Tab Navigation
    
    private var tabNavigationSection: some View {
        HStack(spacing: 0) {
            ForEach(MeshtasticTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Chat List Section
    
    private var chatListSection: some View {
        List(selection: $meshtasticManager.selectedChatRoom) {
            ForEach(sortedChatRooms, id: \.id) { chatRoom in
                ChatRowView(chatRoom: chatRoom, meshtasticManager: meshtasticManager)
                    .tag(chatRoom)
            }
            .onDelete(perform: deleteChatRooms)
        }
        .listStyle(.sidebar)
    }
    
    private var sortedChatRooms: [ChatRoom] {
        meshtasticManager.chatRooms.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    // MARK: - Profile List Section
    
    private var profileListSection: some View {
        List {
            Section("My Profiles") {
                ForEach(meshtasticManager.deviceProfiles, id: \.id) { profile in
                    ProfileRowView(profile: profile, meshtasticManager: meshtasticManager)
                }
                .onDelete(perform: deleteProfiles)
            }
            
            Section("Nearby Nodes") {
                ForEach(nearbyProfiles, id: \.id) { profile in
                    NearbyProfileRowView(profile: profile, meshtasticManager: meshtasticManager)
                }
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            await meshtasticManager.discoverNearbyNodes()
        }
    }
    
    private var nearbyProfiles: [DeviceProfile] {
        meshtasticManager.deviceProfiles.filter { $0.isOnline && $0.id != meshtasticManager.currentProfile?.id }
    }
    
    // MARK: - Network Section
    
    private var networkSection: some View {
        NetworkVisualizerView(meshtasticManager: meshtasticManager)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Menu {
            switch selectedTab {
            case .chats:
                Button("New Direct Chat", systemImage: "person.2") {
                    showingChatCreation = true
                }
                Button("New Broadcast", systemImage: "antenna.radiowaves.left.and.right") {
                    // Create broadcast chat
                }
                Button("New Group Chat", systemImage: "person.3") {
                    showingChatCreation = true
                }
            case .profiles:
                Button("New Profile", systemImage: "person.badge.plus") {
                    showingProfileCreation = true
                }
                Button("Discover Nodes", systemImage: "magnifyingglass") {
                    Task {
                        await meshtasticManager.discoverNearbyNodes()
                    }
                }
            case .network:
                Button("Refresh Network", systemImage: "arrow.clockwise") {
                    Task {
                        await meshtasticManager.discoverNearbyNodes()
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteChatRooms(offsets: IndexSet) {
        for index in offsets {
            let chatRoom = sortedChatRooms[index]
            meshtasticManager.deleteChatRoom(chatRoom)
        }
    }
    
    private func deleteProfiles(offsets: IndexSet) {
        for index in offsets {
            let profile = meshtasticManager.deviceProfiles[index]
            meshtasticManager.deleteProfile(profile)
        }
    }
}

// MARK: - Supporting Enums

enum MeshtasticTab: String, CaseIterable {
    case chats = "Chats"
    case profiles = "Profiles"
    case network = "Network"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .chats: return "message"
        case .profiles: return "person.2"
        case .network: return "network"
        }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chatRoom: ChatRoom
    @ObservedObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        HStack {
            // Chat Type Icon
            Image(systemName: chatRoom.type.icon)
                .font(.title3)
                .foregroundColor(chatRoom.type.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(chatRoom.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if chatRoom.unreadCount > 0 {
                        Text("\(chatRoom.unreadCount)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                if let lastMessage = lastMessageForChat(chatRoom.id) {
                    Text(lastMessage.content.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(RelativeDateTimeFormatter().localizedString(for: chatRoom.lastActivity, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .onTapGesture {
            meshtasticManager.selectedChatRoom = chatRoom
            meshtasticManager.markChatRoomAsRead(chatRoom.id)
        }
    }
    
    private func lastMessageForChat(_ chatRoomId: String) -> MeshtasticMessage? {
        return meshtasticManager.getMessagesForChatRoom(chatRoomId).last
    }
}

// MARK: - Profile Row View

struct ProfileRowView: View {
    let profile: DeviceProfile
    @ObservedObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        HStack {
            Image(systemName: profile.role.icon)
                .font(.title3)
                .foregroundColor(profile.isOnline ? .green : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                
                Text("\(profile.role.description) • \(profile.region.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !profile.callSign.isEmpty {
                    Text(profile.callSign)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let batteryLevel = profile.batteryLevel {
                    Label("\(batteryLevel)%", systemImage: "battery.100")
                        .font(.caption2)
                        .foregroundColor(batteryLevel > 20 ? .green : .red)
                }
                
                Circle()
                    .fill(profile.isOnline ? .green : .gray)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Set as Current") {
                meshtasticManager.setCurrentProfile(profile)
            }
            
            Button("Start Direct Chat") {
                let chatRoom = meshtasticManager.createDirectChat(with: profile.id)
                meshtasticManager.selectedChatRoom = chatRoom
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                meshtasticManager.deleteProfile(profile)
            }
        }
    }
}

// MARK: - Nearby Profile Row View

struct NearbyProfileRowView: View {
    let profile: DeviceProfile
    @ObservedObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        HStack {
            Image(systemName: profile.role.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                
                Text(profile.role.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last seen: \(RelativeDateTimeFormatter().localizedString(for: profile.lastSeen, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button("Chat") {
                let chatRoom = meshtasticManager.createDirectChat(with: profile.id)
                meshtasticManager.selectedChatRoom = chatRoom
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MeshtasticView(deviceManager: DeviceManager())
}
