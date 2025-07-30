import SwiftUI

// MARK: - Chat List View

struct ChatListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var meshtasticManager: MeshtasticManager
    @State private var searchText = ""
    @State private var showingNewChatModal = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search Bar
            searchBarView
            
            // Chat List
            if filteredChatRooms.isEmpty {
                emptyStateView
            } else {
                chatListView
            }
        }
        .background(themeManager.theme.backgroundColor)
        .sheet(isPresented: $showingNewChatModal) {
            NewChatModalView(meshtasticManager: meshtasticManager)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Chats")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            CarbonButton("New", type: .ghost, size: .small) {
                showingNewChatModal = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Search Bar View
    
    private var searchBarView: some View {
        VStack(spacing: 0) {
            CarbonTextField(
                text: $searchText,
                placeholder: "Search chats...",
                label: nil
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
                .background(themeManager.theme.surfaceColor)
        }
    }
    
    // MARK: - Chat List View
    
    private var chatListView: some View {
        List(selection: $meshtasticManager.selectedChatRoom) {
            ForEach(filteredChatRooms, id: \.id) { chatRoom in
                ChatRowView(chatRoom: chatRoom, meshtasticManager: meshtasticManager)
                    .tag(chatRoom)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteChatRooms)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundColor(themeManager.theme.textSecondaryColor)
            
            Text("No chats yet")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Text("Start a conversation with nearby nodes")
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textSecondaryColor)
                .multilineTextAlignment(.center)
            
            CarbonButton("Start Chat", type: .primary) {
                showingNewChatModal = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var filteredChatRooms: [ChatRoom] {
        let rooms = meshtasticManager.chatRooms.sorted { $0.lastActivity > $1.lastActivity }
        
        if searchText.isEmpty {
            return rooms
        } else {
            return rooms.filter { chatRoom in
                chatRoom.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteChatRooms(offsets: IndexSet) {
        for index in offsets {
            let chatRoom = filteredChatRooms[index]
            meshtasticManager.deleteChatRoom(chatRoom)
        }
    }
}

// MARK: - New Chat Modal View

struct NewChatModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedChatType: ChatType = .direct
    @State private var chatName = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("New Chat")
                    .font(themeManager.theme.fontHeading)
                    .foregroundColor(themeManager.theme.textColor)
                
                Spacer()
                
                CarbonButton("×", type: .ghost, size: .small) {
                    dismiss()
                }
            }
            
            // Chat Type Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Type")
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textColor)
                
                HStack(spacing: 8) {
                    ForEach([ChatType.direct, ChatType.broadcast, ChatType.group], id: \.self) { type in
                        CarbonButton(
                            type.description,
                            type: selectedChatType == type ? .primary : .secondary,
                            size: .small
                        ) {
                            selectedChatType = type
                        }
                    }
                }
            }
            
            // Chat Name Field
            CarbonTextField(
                text: $chatName,
                placeholder: "Enter chat name",
                label: "Chat Name"
            )
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                CarbonButton("Cancel", type: .secondary) {
                    dismiss()
                }
                
                CarbonButton("Create Chat", type: .primary) {
                    createChat()
                }
                .disabled(chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .background(themeManager.theme.surfaceColor)
    }
    
    private func createChat() {
        let trimmedName = chatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        switch selectedChatType {
        case .direct:
            // Implementation for direct chat creation
            break
        case .broadcast:
            _ = meshtasticManager.createBroadcastChat(name: trimmedName)
        case .group:
            _ = meshtasticManager.createGroupChat(name: trimmedName, participants: [])
        default:
            break
        }
        
        dismiss()
    }
}

// MARK: - Previews

#Preview {
    ChatListView(meshtasticManager: MeshtasticManager(deviceManager: DeviceManager()))
        .frame(width: 300, height: 500)
        .environmentObject(ThemeManager())
}
