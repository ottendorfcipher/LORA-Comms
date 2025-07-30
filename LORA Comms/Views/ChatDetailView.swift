import SwiftUI

// MARK: - Chat Detail View

struct ChatDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var meshtasticManager: MeshtasticManager
    @State private var messageText = ""
    
    var body: some View {
        if let selectedChatRoom = meshtasticManager.selectedChatRoom {
            VStack(spacing: 0) {
                // Chat Header
                chatHeaderView(for: selectedChatRoom)
                
                // Messages
                messagesView(for: selectedChatRoom)
                
                // Message Input
                messageInputView
            }
            .background(themeManager.theme.backgroundColor)
        } else {
            // No Chat Selected
            VStack(spacing: 16) {
                Image(systemName: "message.badge")
                    .font(.system(size: 48))
                .foregroundColor(themeManager.theme.textSecondaryColor)
                
                Text("Select a chat")
                    .font(themeManager.theme.fontHeading)
                    .foregroundColor(themeManager.theme.textColor)
                
                Text("Choose a conversation to start messaging")
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.backgroundColor)
        }
    }
    
    // MARK: - Chat Header View
    
    private func chatHeaderView(for chatRoom: ChatRoom) -> some View {
        HStack(spacing: 12) {
            Image(systemName: chatRoom.type.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(chatRoom.type.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chatRoom.name)
                    .font(themeManager.theme.fontHeading)
                    .foregroundColor(themeManager.theme.textColor)
                
                Text("\(chatRoom.participants.count) participants")
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textSecondaryColor)
            }
            
            Spacer()
            
            // Actions Menu
            Menu {
                Button("Chat Info") { }
                Button("Clear History") { }
                Divider()
                Button("Archive Chat", role: .destructive) { }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(themeManager.theme.textColor)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Messages View
    
    private func messagesView(for chatRoom: ChatRoom) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(meshtasticManager.getMessagesForChatRoom(chatRoom.id), id: \.id) { message in
                        CarbonMessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                meshtasticManager.markChatRoomAsRead(chatRoom.id)
            }
        }
    }
    
    // MARK: - Message Input View
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeManager.theme.surfaceColor)
            
            HStack(spacing: 12) {
                CarbonTextField(
                    text: $messageText,
                    placeholder: "Type a message...",
                    label: nil
                )
                
                CarbonButton("Send", type: .primary, size: .small) {
                    sendMessage()
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let chatRoom = meshtasticManager.selectedChatRoom else { return }
        
        let message = MeshtasticMessage.createEncryptedMessage(
            fromId: "local", // Placeholder for the actual local user ID
            toId: chatRoom.id,
            chatRoomId: chatRoom.id,
            text: text
        )
        
        Task {
            await meshtasticManager.sendMessage(message)
            
            await MainActor.run {
                messageText = ""
            }
        }
    }
}

// MARK: - Carbon Message Bubble View

struct CarbonMessageBubbleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: MeshtasticMessage
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                Text(message.secureDisplayText)
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.theme.interactiveColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack(spacing: 4) {
                        Text(message.timestamp, style: .time)
                            .font(themeManager.theme.font)
                            .foregroundColor(themeManager.theme.textSecondaryColor)
                        
                        // Delivery Status
                        Image(systemName: message.deliveryStatus.icon)
                            .font(.system(size: 8))
                            .foregroundColor(message.deliveryStatus.color)
                    }
                }
                .frame(maxWidth: .infinity * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Sender Name
                    Text("Node \(message.fromId)")
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                    
                Text(message.secureDisplayText)
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.theme.surfaceColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text(message.timestamp, style: .time)
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                }
                .frame(maxWidth: .infinity * 0.7, alignment: .leading)
                
                Spacer()
            }
        }
        .accessibilityLabel(isFromCurrentUser ? "You said" : "Message from Node \(message.fromId)")
        .accessibilityValue(message.content.displayText)
    }
    
    private var isFromCurrentUser: Bool {
        // This would check against the current profile ID
        // For now, just check if fromId matches some criteria
        return message.fromId == "local" // Placeholder logic
    }
}

// MARK: - Previews

#Preview {
    ChatDetailView(meshtasticManager: MeshtasticManager(deviceManager: DeviceManager()))
        .frame(width: 500, height: 600)
        .environmentObject(ThemeManager())
}
