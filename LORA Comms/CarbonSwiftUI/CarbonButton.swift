import SwiftUI

// MARK: - Carbon Button Component

public struct CarbonButton: View {
    // MARK: - Properties
    
    private let text: String
    private let type: ButtonType
    private let size: ButtonSize
    private let isDisabled: Bool
    private let action: () -> Void
    
    // MARK: - Button Types
    
    public enum ButtonType {
        case primary
        case secondary
        case tertiary
        case ghost
        case danger
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return CarbonTheme.ColorPalette.interactive
            case .secondary:
                return CarbonTheme.ColorPalette.surface
            case .tertiary:
                return Color.clear
            case .ghost:
                return Color.clear
            case .danger:
                return CarbonTheme.ColorPalette.red
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary, .danger:
                return CarbonTheme.ColorPalette.textPrimary
            case .secondary, .tertiary, .ghost:
                return CarbonTheme.ColorPalette.textPrimary
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary, .danger:
                return Color.clear
            case .secondary:
                return CarbonTheme.ColorPalette.surface
            case .tertiary:
                return CarbonTheme.ColorPalette.interactive
            case .ghost:
                return Color.clear
            }
        }
    }
    
    // MARK: - Button Sizes
    
    public enum ButtonSize {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium:
                return EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
            case .large:
                return EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small:
                return 12
            case .medium:
                return 14
            case .large:
                return 16
            }
        }
    }
    
    // MARK: - Initializer
    
    public init(
        _ text: String,
        type: ButtonType = .primary,
        size: ButtonSize = .medium,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.type = type
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: action) {
            Text(text)
                .font(CarbonTheme.Typography.plexSans(size: size.fontSize, weight: .medium))
                .foregroundColor(isDisabled ? CarbonTheme.ColorPalette.textSecondary : type.textColor)
                .padding(size.padding)
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isDisabled ? CarbonTheme.ColorPalette.surface : type.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isDisabled ? CarbonTheme.ColorPalette.surface : type.borderColor, lineWidth: 1)
        )
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(text)
        .accessibilityHint(isDisabled ? "Button is disabled" : "")
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 16) {
        CarbonButton("Primary Button", type: .primary) { }
        CarbonButton("Secondary Button", type: .secondary) { }
        CarbonButton("Tertiary Button", type: .tertiary) { }
        CarbonButton("Ghost Button", type: .ghost) { }
        CarbonButton("Danger Button", type: .danger) { }
        CarbonButton("Disabled Button", isDisabled: true) { }
    }
    .padding()
    .background(CarbonTheme.ColorPalette.background)
}
