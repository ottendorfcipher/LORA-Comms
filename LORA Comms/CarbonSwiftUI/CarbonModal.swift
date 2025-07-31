import SwiftUI

// MARK: - Carbon Modal Component

public struct CarbonModal: View {
    // MARK: - Properties
    
    @Binding private var isPresented: Bool
    private let title: String
    private let message: String?
    private let primaryAction: ModalAction?
    private let secondaryAction: ModalAction?
    private let tertiaryAction: ModalAction?
    private let size: ModalSize
    private let isDismissible: Bool
    
    // MARK: - Modal Action
    
    public struct ModalAction {
        let title: String
        let type: CarbonButton.ButtonType
        let action: () -> Void
        
        public init(title: String, type: CarbonButton.ButtonType = .primary, action: @escaping () -> Void) {
            self.title = title
            self.type = type
            self.action = action
        }
    }
    
    // MARK: - Modal Size
    
    public enum ModalSize {
        case small
        case medium
        case large
        
        var width: CGFloat {
            switch self {
            case .small: return 320
            case .medium: return 480
            case .large: return 640
            }
        }
        
        var maxHeight: CGFloat {
            switch self {
            case .small: return 240
            case .medium: return 360
            case .large: return 480
            }
        }
    }
    
    // MARK: - Initializer
    
    public init(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        primaryAction: ModalAction? = nil,
        secondaryAction: ModalAction? = nil,
        tertiaryAction: ModalAction? = nil,
        size: ModalSize = .medium,
        isDismissible: Bool = true
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.tertiaryAction = tertiaryAction
        self.size = size
        self.isDismissible = isDismissible
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Overlay background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if isDismissible {
                        isPresented = false
                    }
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(title)
                        .font(CarbonTheme.Typography.plexSans(size: 20, weight: .semibold))
                        .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    
                    Spacer()
                    
                    if isDismissible {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Close modal")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(CarbonTheme.ColorPalette.surface)
                
                // Content
                if let message = message {
                    ScrollView {
                        Text(message)
                            .font(CarbonTheme.Typography.plexSans(size: 14))
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                    }
                    .frame(maxHeight: size.maxHeight - 120) // Account for header and footer
                }
                
                // Action buttons
                if primaryAction != nil || secondaryAction != nil || tertiaryAction != nil {
                    Divider()
                        .background(CarbonTheme.ColorPalette.surface)
                    
                    HStack(spacing: 12) {
                        Spacer()
                        
                        if let tertiaryAction = tertiaryAction {
                            CarbonButton(
                                tertiaryAction.title,
                                type: tertiaryAction.type,
                                size: .medium
                            ) {
                                tertiaryAction.action()
                                if isDismissible {
                                    isPresented = false
                                }
                            }
                        }
                        
                        if let secondaryAction = secondaryAction {
                            CarbonButton(
                                secondaryAction.title,
                                type: secondaryAction.type,
                                size: .medium
                            ) {
                                secondaryAction.action()
                                if isDismissible {
                                    isPresented = false
                                }
                            }
                        }
                        
                        if let primaryAction = primaryAction {
                            CarbonButton(
                                primaryAction.title,
                                type: primaryAction.type,
                                size: .medium
                            ) {
                                primaryAction.action()
                                if isDismissible {
                                    isPresented = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(CarbonTheme.ColorPalette.surface)
                }
            }
            .frame(width: size.width)
            .background(CarbonTheme.ColorPalette.background)
            .cornerRadius(0) // Carbon uses sharp corners
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

// MARK: - Modal Modifier

extension View {
    public func carbonModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            isPresented.wrappedValue ? AnyView(content()) : AnyView(EmptyView())
        )
    }
}

// MARK: - Previews

#Preview {
    @State var isModalPresented = true
    
    return ZStack {
        CarbonTheme.ColorPalette.background
            .ignoresSafeArea()
        
        if isModalPresented {
            CarbonModal(
                isPresented: $isModalPresented,
                title: "Confirm Device Connection",
                message: "Are you sure you want to connect to this LoRa device? This will disconnect any currently connected devices.",
                primaryAction: CarbonModal.ModalAction(
                    title: "Connect",
                    type: .primary
                ) {
                    print("Connect action")
                },
                secondaryAction: CarbonModal.ModalAction(
                    title: "Cancel",
                    type: .secondary
                ) {
                    print("Cancel action")
                }
            )
        }
    }
}
