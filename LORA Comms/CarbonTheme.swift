import SwiftUI

// MARK: - Carbon Design System Theme

public struct CarbonTheme {
    // MARK: - Color Palette (IBM Design Language V10)
    public struct ColorPalette {
        // Primary UI Colors
        public static let background = Color(hex: "#262626")        // Gray 90
        public static let backgroundHover = Color(hex: "#353535")   // Gray 80
        public static let surface = Color(hex: "#393939")           // Gray 70
        public static let surfaceHover = Color(hex: "#4C4C4C")      // Gray 60
        public static let field = Color(hex: "#262626")            // Gray 90
        
        // Text Colors
        public static let textPrimary = Color(hex: "#F4F4F4")      // Gray 10
        public static let textSecondary = Color(hex: "#C6C6C6")    // Gray 30
        public static let textTertiary = Color(hex: "#A8A8A8")     // Gray 40
        public static let textDisabled = Color(hex: "#6F6F6F")     // Gray 50
        public static let textInverse = Color(hex: "#161616")      // Gray 100
        
        // Interactive Colors
        public static let interactive = Color(hex: "#4589FF")      // Blue 60
        public static let interactiveHover = Color(hex: "#5596FF") // Blue 50
        public static let interactiveActive = Color(hex: "#0043CE") // Blue 80
        
        // Status Colors
        public static let success = Color(hex: "#24A148")          // Green 50
        public static let successHover = Color(hex: "#198038")     // Green 60
        public static let warning = Color(hex: "#F1C21B")          // Yellow 30
        public static let warningHover = Color(hex: "#D2A106")     // Yellow 40
        public static let error = Color(hex: "#DA1E28")            // Red 60
        public static let errorHover = Color(hex: "#B81922")       // Red 70
        public static let info = Color(hex: "#4589FF")             // Blue 60
        
        // Accent Colors
        public static let accent = Color(hex: "#0043CE")           // Blue 80
        public static let purple = Color(hex: "#8A3FFC")           // Purple 60
        public static let cyan = Color(hex: "#1192E8")             // Cyan 50
        public static let teal = Color(hex: "#009D9A")             // Teal 50
        public static let magenta = Color(hex: "#EE5396")          // Magenta 50
        
        // Legacy aliases for backward compatibility
        public static let green = success
        public static let yellow = warning
        public static let red = error
        
        // Borders and Dividers
        public static let border = Color(hex: "#525252")           // Gray 70
        public static let borderSubtle = Color(hex: "#393939")     // Gray 80
        public static let divider = Color(hex: "#525252")          // Gray 70
        
        // Overlays
        public static let overlay = Color.black.opacity(0.5)
        public static let overlayLight = Color.black.opacity(0.25)
        public static let focus = Color(hex: "#4589FF")            // Blue 60
        
        // Light theme variants (for future use)
        public struct Light {
            public static let background = Color(hex: "#FFFFFF")    // White
            public static let surface = Color(hex: "#F4F4F4")       // Gray 10
            public static let textPrimary = Color(hex: "#161616")   // Gray 100
            public static let textSecondary = Color(hex: "#525252") // Gray 70
            public static let interactive = Color(hex: "#0F62FE")   // Blue 60 (light)
        }
    }
    
    // MARK: - Typography (IBM Plex Sans)
    public struct Typography {
        // Font family helper
        public static func plexSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
        
        // Typography scale based on Carbon Design System
        public static let display01 = plexSans(size: 42, weight: .light)      // 42px Light
        public static let display02 = plexSans(size: 42, weight: .semibold)   // 42px Semibold
        public static let display03 = plexSans(size: 54, weight: .light)      // 54px Light
        public static let display04 = plexSans(size: 54, weight: .semibold)   // 54px Semibold
        
        public static let heading01 = plexSans(size: 14, weight: .semibold)   // 14px Semibold
        public static let heading02 = plexSans(size: 16, weight: .semibold)   // 16px Semibold
        public static let heading03 = plexSans(size: 20, weight: .regular)    // 20px Regular
        public static let heading04 = plexSans(size: 28, weight: .regular)    // 28px Regular
        public static let heading05 = plexSans(size: 32, weight: .regular)    // 32px Regular
        public static let heading06 = plexSans(size: 42, weight: .light)      // 42px Light
        public static let heading07 = plexSans(size: 54, weight: .light)      // 54px Light
        
        public static let body01 = plexSans(size: 14, weight: .regular)       // 14px Regular
        public static let body02 = plexSans(size: 16, weight: .regular)       // 16px Regular
        public static let bodyCompact01 = plexSans(size: 14, weight: .regular) // 14px Regular (compact)
        public static let bodyCompact02 = plexSans(size: 16, weight: .regular) // 16px Regular (compact)
        
        public static let caption01 = plexSans(size: 12, weight: .regular)    // 12px Regular
        public static let caption02 = plexSans(size: 14, weight: .regular)    // 14px Regular
        
        public static let label01 = plexSans(size: 12, weight: .regular)      // 12px Regular
        public static let label02 = plexSans(size: 14, weight: .regular)      // 14px Regular
        
        public static let helperText01 = plexSans(size: 12, weight: .regular) // 12px Regular
        public static let helperText02 = plexSans(size: 14, weight: .regular) // 14px Regular
        
        public static let legal01 = plexSans(size: 12, weight: .regular)      // 12px Regular
        public static let legal02 = plexSans(size: 14, weight: .regular)      // 14px Regular
        
        public static let code01 = Font.system(size: 12, weight: .regular, design: .monospaced) // 12px Mono
        public static let code02 = Font.system(size: 14, weight: .regular, design: .monospaced) // 14px Mono
    }
    
    // MARK: - Spacing (Layout Tokens)
    public struct Spacing {
        public static let spacing01: CGFloat = 2      // 0.125rem
        public static let spacing02: CGFloat = 4      // 0.25rem
        public static let spacing03: CGFloat = 8      // 0.5rem
        public static let spacing04: CGFloat = 12     // 0.75rem
        public static let spacing05: CGFloat = 16     // 1rem
        public static let spacing06: CGFloat = 24     // 1.5rem
        public static let spacing07: CGFloat = 32     // 2rem
        public static let spacing08: CGFloat = 40     // 2.5rem
        public static let spacing09: CGFloat = 48     // 3rem
        public static let spacing10: CGFloat = 64     // 4rem
        public static let spacing11: CGFloat = 80     // 5rem
        public static let spacing12: CGFloat = 96     // 6rem
        public static let spacing13: CGFloat = 160    // 10rem
        
        // Semantic spacing
        public static let container = spacing05       // 16px
        public static let section = spacing07         // 32px
        public static let component = spacing03       // 8px
        public static let element = spacing02         // 4px
    }
    
    // MARK: - Layout Tokens
    public struct Layout {
        public static let size01: CGFloat = 16        // 1rem
        public static let size02: CGFloat = 20        // 1.25rem
        public static let size03: CGFloat = 24        // 1.5rem
        public static let size04: CGFloat = 28        // 1.75rem
        public static let size05: CGFloat = 32        // 2rem
        public static let size06: CGFloat = 40        // 2.5rem
        public static let size07: CGFloat = 48        // 3rem
        public static let size08: CGFloat = 56        // 3.5rem
        public static let size09: CGFloat = 64        // 4rem
        public static let size10: CGFloat = 80        // 5rem
        
        // Container widths
        public static let containerSmall: CGFloat = 320
        public static let containerMedium: CGFloat = 672
        public static let containerLarge: CGFloat = 1056
        public static let containerMax: CGFloat = 1584
        
        // Common component heights
        public static let buttonHeight: CGFloat = size05      // 32px
        public static let inputHeight: CGFloat = size05       // 32px
        public static let sidebarWidth: CGFloat = 240         // Collapsed: 48px
        public static let sidebarCollapsedWidth: CGFloat = 48
    }
    
    // MARK: - Border Radius
    public struct BorderRadius {
        public static let none: CGFloat = 0
        public static let small: CGFloat = 2
        public static let medium: CGFloat = 4
        public static let large: CGFloat = 8
    }
    
    // MARK: - Shadows
    public struct Shadow {
        public struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        public static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        public static let small = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        public static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        public static let large = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        public static let overlay = ShadowStyle(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Animation Durations
    public struct Animation {
        public static let fast: Double = 0.1
        public static let moderate: Double = 0.15
        public static let slow: Double = 0.24
        public static let slower: Double = 0.4
    }

    // MARK: - Iconography (Carbon Icons)
    public struct Icons {
        // Navigation
        public static let menu = Image(systemName: "line.horizontal.3")
        public static let close = Image(systemName: "xmark")
        public static let chevronDown = Image(systemName: "chevron.down")
        public static let chevronUp = Image(systemName: "chevron.up")
        public static let chevronLeft = Image(systemName: "chevron.left")
        public static let chevronRight = Image(systemName: "chevron.right")
        public static let arrow = Image(systemName: "arrow.right")
        
        // Actions
        public static let add = Image(systemName: "plus")
        public static let edit = Image(systemName: "pencil")
        public static let delete = Image(systemName: "trash")
        public static let copy = Image(systemName: "doc.on.doc")
        public static let download = Image(systemName: "arrow.down.circle")
        public static let upload = Image(systemName: "arrow.up.circle")
        public static let refresh = Image(systemName: "arrow.clockwise")
        public static let search = Image(systemName: "magnifyingglass")
        public static let filter = Image(systemName: "line.horizontal.3.decrease.circle")
        public static let sort = Image(systemName: "arrow.up.arrow.down")
        
        // Communication
        public static let message = Image(systemName: "message")
        public static let send = Image(systemName: "paperplane")
        public static let phone = Image(systemName: "phone")
        public static let email = Image(systemName: "envelope")
        
        // Device/Hardware
        public static let bluetooth = Image(systemName: "bluetooth")
        public static let wifi = Image(systemName: "wifi")
        public static let antenna = Image(systemName: "antenna.radiowaves.left.and.right")
        public static let device = Image(systemName: "desktopcomputer")
        public static let usb = Image(systemName: "cable.connector")
        
        // Status
        public static let success = Image(systemName: "checkmark.circle.fill")
        public static let warning = Image(systemName: "exclamationmark.triangle.fill")
        public static let error = Image(systemName: "xmark.circle.fill")
        public static let info = Image(systemName: "info.circle.fill")
        public static let notification = Image(systemName: "bell")
        
        // Settings
        public static let settings = Image(systemName: "gear")
        public static let preferences = Image(systemName: "slider.horizontal.3")
        public static let security = Image(systemName: "lock.shield")
        public static let lock = Image(systemName: "lock.fill")
        public static let unlock = Image(systemName: "lock.open.fill")
        
        // Network
        public static let network = Image(systemName: "network")
        public static let server = Image(systemName: "server.rack")
        public static let cloud = Image(systemName: "cloud")
        public static let globe = Image(systemName: "globe")
        
        // User
        public static let user = Image(systemName: "person.circle")
        public static let users = Image(systemName: "person.2.circle")
        public static let profile = Image(systemName: "person.crop.circle")
        
        // Files
        public static let folder = Image(systemName: "folder")
        public static let document = Image(systemName: "doc")
        public static let image = Image(systemName: "photo")
        public static let video = Image(systemName: "video")
        
        // Miscellaneous
        public static let home = Image(systemName: "house")
        public static let star = Image(systemName: "star")
        public static let bookmark = Image(systemName: "bookmark")
        public static let calendar = Image(systemName: "calendar")
        public static let clock = Image(systemName: "clock")
        public static let location = Image(systemName: "location")
        public static let map = Image(systemName: "map")
        public static let chart = Image(systemName: "chart.bar")
        public static let graph = Image(systemName: "chart.line.uptrend.xyaxis")
    }
}


