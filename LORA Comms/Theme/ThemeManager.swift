import SwiftUI

// MARK: - App Theme Structure

struct AppTheme {
    let primaryColor: Color
    let backgroundColor: Color
    let surfaceColor: Color
    let textColor: Color
    let textSecondaryColor: Color
    let interactiveColor: Color
    let successColor: Color
    let errorColor: Color
    let warningColor: Color
    let accentColor: Color
    let cornerRadius: CGFloat
    let font: Font
    let fontSecondary: Font
    let fontHeading: Font
    let spacing: CGFloat
    let elevation: CGFloat
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme
    
    init() {
        self.theme = AppTheme(
            // Carbon Design System Colors
            primaryColor: Color(hex: "#4589FF"),        // IBM Blue 60
            backgroundColor: Color(hex: "#262626"),      // Gray 100
            surfaceColor: Color(hex: "#393939"),         // Gray 90
            textColor: Color(hex: "#F4F4F4"),           // Gray 10
            textSecondaryColor: Color(hex: "#C6C6C6"),  // Gray 30
            interactiveColor: Color(hex: "#4589FF"),     // Blue 60
            successColor: Color(hex: "#24A148"),         // Green 50
            errorColor: Color(hex: "#DA1E28"),          // Red 60
            warningColor: Color(hex: "#F1C21B"),        // Yellow 30
            accentColor: Color(hex: "#0043CE"),         // Blue 80
            
            // Design Tokens
            cornerRadius: 4,                             // Carbon uses minimal radius
            font: .system(size: 14, weight: .regular, design: .default),
            fontSecondary: .system(size: 12, weight: .regular, design: .default),
            fontHeading: .system(size: 20, weight: .semibold, design: .default),
            spacing: 16,
            elevation: 2
        )
    }
    
    // MARK: - Theme Variants
    
    func switchToLightTheme() {
        theme = AppTheme(
            primaryColor: Color(hex: "#0F62FE"),        // IBM Blue 60 (light)
            backgroundColor: Color(hex: "#FFFFFF"),      // White
            surfaceColor: Color(hex: "#F4F4F4"),         // Gray 10
            textColor: Color(hex: "#161616"),           // Gray 100
            textSecondaryColor: Color(hex: "#525252"),  // Gray 70
            interactiveColor: Color(hex: "#0F62FE"),     // Blue 60
            successColor: Color(hex: "#198038"),         // Green 60
            errorColor: Color(hex: "#DA1E28"),          // Red 60
            warningColor: Color(hex: "#F1C21B"),        // Yellow 30
            accentColor: Color(hex: "#002D9C"),         // Blue 90
            cornerRadius: 4,
            font: .system(size: 14, weight: .regular, design: .default),
            fontSecondary: .system(size: 12, weight: .regular, design: .default),
            fontHeading: .system(size: 20, weight: .semibold, design: .default),
            spacing: 16,
            elevation: 2
        )
    }
    
    func switchToDarkTheme() {
        theme = AppTheme(
            primaryColor: Color(hex: "#4589FF"),        // IBM Blue 60
            backgroundColor: Color(hex: "#262626"),      // Gray 100
            surfaceColor: Color(hex: "#393939"),         // Gray 90
            textColor: Color(hex: "#F4F4F4"),           // Gray 10
            textSecondaryColor: Color(hex: "#C6C6C6"),  // Gray 30
            interactiveColor: Color(hex: "#4589FF"),     // Blue 60
            successColor: Color(hex: "#24A148"),         // Green 50
            errorColor: Color(hex: "#DA1E28"),          // Red 60
            warningColor: Color(hex: "#F1C21B"),        // Yellow 30
            accentColor: Color(hex: "#0043CE"),         // Blue 80
            cornerRadius: 4,
            font: .system(size: 14, weight: .regular, design: .default),
            fontSecondary: .system(size: 12, weight: .regular, design: .default),
            fontHeading: .system(size: 20, weight: .semibold, design: .default),
            spacing: 16,
            elevation: 2
        )
    }
    
    // MARK: - Semantic Colors for Specific Use Cases
    
    var encryptedMessageColor: Color {
        return theme.successColor
    }
    
    var unencryptedMessageColor: Color {
        return theme.warningColor
    }
    
    var failedMessageColor: Color {
        return theme.errorColor
    }
    
    var connectedStatusColor: Color {
        return theme.successColor
    }
    
    var disconnectedStatusColor: Color {
        return theme.errorColor
    }
    
    var weakSignalColor: Color {
        return theme.warningColor
    }
    
    var strongSignalColor: Color {
        return theme.successColor
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - SwiftUI Environment Key

struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
