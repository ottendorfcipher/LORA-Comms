import SwiftUI

// MARK: - Carbon Design System Theme

public struct CarbonTheme {
    // MARK: - Color Palette (IBM Design Language V10)
    public struct ColorPalette {
        // Primary UI Colors
        public static let background = Color(hex: "#262626")
        public static let surface = Color(hex: "#393939")
        
        // Text Colors
        public static let textPrimary = Color(hex: "#F4F4F4")
        public static let textSecondary = Color(hex: "#C6C6C6")
        
        // Interactive Colors
        public static let interactive = Color(hex: "#4589FF")
        
        // Accent Colors
        public static let accent = Color(hex: "#0043CE")
        public static let green = Color(hex: "#24A148")
        public static let yellow = Color(hex: "#F1C21B")
        public static let red = Color(hex: "#DA1E28")
    }

    // MARK: - Typography (IBM Plex)
    public struct Typography {
        public static func plexSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
    }

    // MARK: - Iconography (Carbon Icons)
    public struct Icons {
        // Example icons - the full library would be extensive
        public static let add = Image(systemName: "plus")
        public static let bluetooth = Image(systemName: "bluetooth")
        public static let chevronDown = Image(systemName: "chevron.down")
        public static let settings = Image(systemName: "gear")
        // ... and so on
    }
}


