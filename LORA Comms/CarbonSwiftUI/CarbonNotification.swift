import SwiftUI

// MARK: - Carbon Notification Component

public struct CarbonNotification: View {
    // MARK: - Properties
    
    private let type: NotificationType
    private let title: String
    private let message: String?
    private let action: NotificationAction?
    private let onDismiss: (() -> Void)?
    private let autoDismiss: Bool
    private let dismissAfter: TimeInterval
    
    @State private var isVisible = false
    @State private var dismissTimer: Timer?
    
    // MARK: - Notification Types
    
    public enum NotificationType {
        case info
        case success
        case warning
        case error
        
        var backgroundColor: Color {
            switch self {
            case .info:
                return CarbonTheme.ColorPalette.interactive
            case .success:
                return CarbonTheme.ColorPalette.green
            case .warning:
                return CarbonTheme.ColorPalette.yellow
            case .error:
                return CarbonTheme.ColorPalette.red
            }
        }
        
        var textColor: Color {
            switch self {
            case .info, .success, .error:
                return CarbonTheme.ColorPalette.textPrimary
            case .warning:
                return Color.black // Better contrast on yellow
            }
        }
        
        var iconName: String {
            switch self {
            case .info:
                return "info.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
    }
    
    // MARK: - Notification Action
    
    public struct NotificationAction {
        let title: String
        let action: () -> Void
        
        public init(title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
    }
    
    // MARK: - Initializer
    
    public init(
        type: NotificationType,
        title: String,
        message: String? = nil,
        action: NotificationAction? = nil,
        onDismiss: (() -> Void)? = nil,
        autoDismiss: Bool = true,
        dismissAfter: TimeInterval = 5.0
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.action = action
        self.onDismiss = onDismiss
        self.autoDismiss = autoDismiss
        self.dismissAfter = dismissAfter
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type.iconName)
                .foregroundColor(type.textColor)
                .font(.system(size: 16, weight: .medium))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CarbonTheme.Typography.plexSans(size: 14, weight: .semibold))
                    .foregroundColor(type.textColor)
                
                if let message = message {
                    Text(message)
                        .font(CarbonTheme.Typography.plexSans(size: 12))
                        .foregroundColor(type.textColor.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Action button
            if let action = action {
                Button(action.title) {
                    action.action()
                    dismiss()
                }
                .font(CarbonTheme.Typography.plexSans(size: 12, weight: .medium))
                .foregroundColor(type.textColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(type.textColor.opacity(0.5), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
            }
            
            // Dismiss button
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(type.textColor.opacity(0.7))
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(0) // Carbon uses sharp corners
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
            
            if autoDismiss {
                dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissAfter, repeats: false) { _ in
                    dismiss()
                }
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss?()
        }
    }
}

// MARK: - Notification Manager

public class CarbonNotificationManager: ObservableObject {
    @Published public var notifications: [NotificationModel] = []
    
    public struct NotificationModel: Identifiable {
        public let id = UUID()
        let notification: CarbonNotification
        
        public init(notification: CarbonNotification) {
            self.notification = notification
        }
    }
    
    public init() {}
    
    public func show(
        type: CarbonNotification.NotificationType,
        title: String,
        message: String? = nil,
        action: CarbonNotification.NotificationAction? = nil,
        autoDismiss: Bool = true,
        dismissAfter: TimeInterval = 5.0
    ) {
        let notification = CarbonNotification(
            type: type,
            title: title,
            message: message,
            action: action,
            onDismiss: { [weak self] in
                self?.removeNotification(at: 0)
            },
            autoDismiss: autoDismiss,
            dismissAfter: dismissAfter
        )
        
        let model = NotificationModel(notification: notification)
        
        DispatchQueue.main.async {
            self.notifications.insert(model, at: 0)
            
            // Limit to 3 notifications
            if self.notifications.count > 3 {
                self.notifications.removeLast()
            }
        }
    }
    
    private func removeNotification(at index: Int) {
        DispatchQueue.main.async {
            if index < self.notifications.count {
                self.notifications.remove(at: index)
            }
        }
    }
    
    public func clear() {
        DispatchQueue.main.async {
            self.notifications.removeAll()
        }
    }
}

// MARK: - Notification Container View

public struct CarbonNotificationContainer: View {
    @ObservedObject private var manager: CarbonNotificationManager
    
    public init(manager: CarbonNotificationManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.notifications) { model in
                model.notification
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: manager.notifications.count)
    }
}

// MARK: - View Extension

extension View {
    public func carbonNotifications(manager: CarbonNotificationManager) -> some View {
        self.overlay(
            CarbonNotificationContainer(manager: manager)
                .padding(.top, 60) // Account for window title bar
                .padding(.horizontal, 16),
            alignment: .top
        )
    }
}

// MARK: - Environment Key

struct NotificationManagerKey: EnvironmentKey {
    static let defaultValue = CarbonNotificationManager()
}

extension EnvironmentValues {
    public var notificationManager: CarbonNotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
    }
}

// MARK: - Previews

#Preview {
    @StateObject var manager = CarbonNotificationManager()
    
    return VStack(spacing: 20) {
        Button("Show Info") {
            manager.show(type: .info, title: "Device Connected", message: "Successfully connected to LoRa device.")
        }
        
        Button("Show Success") {
            manager.show(type: .success, title: "Message Sent", message: "Your encrypted message was delivered successfully.")
        }
        
        Button("Show Warning") {
            manager.show(type: .warning, title: "Weak Signal", message: "Signal strength is low. Message delivery may be delayed.")
        }
        
        Button("Show Error") {
            manager.show(type: .error, title: "Connection Failed", message: "Unable to connect to the LoRa device. Please check your connection.")
        }
        
        Button("Show with Action") {
            manager.show(
                type: .info,
                title: "New Message",
                message: "You have received a new encrypted message.",
                action: CarbonNotification.NotificationAction(title: "View") {
                    print("View action tapped")
                }
            )
        }
    }
    .padding()
    .background(CarbonTheme.ColorPalette.background)
    .carbonNotifications(manager: manager)
}
