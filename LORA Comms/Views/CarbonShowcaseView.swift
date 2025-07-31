import SwiftUI

// MARK: - Carbon Design System Showcase

struct CarbonShowcaseView: View {
    @State private var textFieldValue = ""
    @State private var isModalPresented = false
    @State private var progressValue: Double = 65
    @State private var selectedTab = "colors"
    @StateObject private var notificationManager = CarbonNotificationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Navigation
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.id) { tab in
                        Button(action: { selectedTab = tab.id }) {
                            Text(tab.title)
                                .font(CarbonTheme.Typography.body01)
                                .foregroundColor(selectedTab == tab.id ? CarbonTheme.ColorPalette.interactive : CarbonTheme.ColorPalette.textSecondary)
                                .padding(.horizontal, CarbonTheme.Spacing.spacing05)
                                .padding(.vertical, CarbonTheme.Spacing.spacing03)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            Rectangle()
                                .fill(selectedTab == tab.id ? CarbonTheme.ColorPalette.surface : Color.clear)
                        )
                    }
                    Spacer()
                }
                .background(CarbonTheme.ColorPalette.background)
                
                Divider()
                    .background(CarbonTheme.ColorPalette.border)
                
                // Content
                ScrollView {
                    switch selectedTab {
                    case "colors":
                        colorShowcase
                    case "typography":
                        typographyShowcase
                    case "components":
                        componentShowcase
                    case "spacing":
                        spacingShowcase
                    default:
                        colorShowcase
                    }
                }
                .background(CarbonTheme.ColorPalette.background)
            }
        }
        .navigationTitle("Carbon Design System")
        .background(CarbonTheme.ColorPalette.background)
        .carbonNotifications(manager: notificationManager)
        .sheet(isPresented: $isModalPresented) {
            modalContent
        }
    }
    
    // MARK: - Tab Data
    
    private var tabs: [TabModel] {
        [
            TabModel(id: "colors", title: "Colors"),
            TabModel(id: "typography", title: "Typography"),
            TabModel(id: "components", title: "Components"),
            TabModel(id: "spacing", title: "Spacing")
        ]
    }
    
    private struct TabModel {
        let id: String
        let title: String
    }
    
    // MARK: - Color Showcase
    
    private var colorShowcase: some View {
        LazyVStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing06) {
            // Primary Colors
            colorSection("Primary Colors", colors: [
                ("Background", CarbonTheme.ColorPalette.background),
                ("Surface", CarbonTheme.ColorPalette.surface),
                ("Interactive", CarbonTheme.ColorPalette.interactive),
                ("Interactive Hover", CarbonTheme.ColorPalette.interactiveHover)
            ])
            
            // Text Colors
            colorSection("Text Colors", colors: [
                ("Text Primary", CarbonTheme.ColorPalette.textPrimary),
                ("Text Secondary", CarbonTheme.ColorPalette.textSecondary),
                ("Text Tertiary", CarbonTheme.ColorPalette.textTertiary),
                ("Text Disabled", CarbonTheme.ColorPalette.textDisabled)
            ])
            
            // Status Colors
            colorSection("Status Colors", colors: [
                ("Success", CarbonTheme.ColorPalette.success),
                ("Warning", CarbonTheme.ColorPalette.warning),
                ("Error", CarbonTheme.ColorPalette.error),
                ("Info", CarbonTheme.ColorPalette.info)
            ])
            
            // Accent Colors
            colorSection("Accent Colors", colors: [
                ("Purple", CarbonTheme.ColorPalette.purple),
                ("Cyan", CarbonTheme.ColorPalette.cyan),
                ("Teal", CarbonTheme.ColorPalette.teal),
                ("Magenta", CarbonTheme.ColorPalette.magenta)
            ])
        }
        .padding(CarbonTheme.Spacing.spacing05)
    }
    
    private func colorSection(_ title: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text(title)
                .font(CarbonTheme.Typography.heading03)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: CarbonTheme.Spacing.spacing03) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, colorInfo in
                    HStack(spacing: CarbonTheme.Spacing.spacing03) {
                        Rectangle()
                            .fill(colorInfo.1)
                            .frame(width: 32, height: 32)
                            .cornerRadius(CarbonTheme.BorderRadius.small)
                        
                        Text(colorInfo.0)
                            .font(CarbonTheme.Typography.body01)
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                        
                        Spacer()
                    }
                    .padding(CarbonTheme.Spacing.spacing03)
                    .background(CarbonTheme.ColorPalette.surface)
                    .cornerRadius(CarbonTheme.BorderRadius.small)
                }
            }
        }
    }
    
    // MARK: - Typography Showcase
    
    private var typographyShowcase: some View {
        LazyVStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing06) {
            typographySection("Display Styles", styles: [
                ("Display 01", CarbonTheme.Typography.display01),
                ("Display 02", CarbonTheme.Typography.display02)
            ])
            
            typographySection("Headings", styles: [
                ("Heading 01", CarbonTheme.Typography.heading01),
                ("Heading 02", CarbonTheme.Typography.heading02),
                ("Heading 03", CarbonTheme.Typography.heading03),
                ("Heading 04", CarbonTheme.Typography.heading04)
            ])
            
            typographySection("Body Text", styles: [
                ("Body 01", CarbonTheme.Typography.body01),
                ("Body 02", CarbonTheme.Typography.body02),
                ("Body Compact 01", CarbonTheme.Typography.bodyCompact01)
            ])
            
            typographySection("Supporting Text", styles: [
                ("Caption 01", CarbonTheme.Typography.caption01),
                ("Label 01", CarbonTheme.Typography.label01),
                ("Helper Text 01", CarbonTheme.Typography.helperText01),
                ("Code 01", CarbonTheme.Typography.code01)
            ])
        }
        .padding(CarbonTheme.Spacing.spacing05)
    }
    
    private func typographySection(_ title: String, styles: [(String, Font)]) -> some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing04) {
            Text(title)
                .font(CarbonTheme.Typography.heading03)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
                ForEach(Array(styles.enumerated()), id: \.offset) { _, style in
                    VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing02) {
                        Text(style.0)
                            .font(CarbonTheme.Typography.caption01)
                            .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                        
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(style.1)
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    }
                    .padding(CarbonTheme.Spacing.spacing04)
                    .background(CarbonTheme.ColorPalette.surface)
                    .cornerRadius(CarbonTheme.BorderRadius.small)
                }
            }
        }
    }
    
    // MARK: - Component Showcase
    
    private var componentShowcase: some View {
        LazyVStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing06) {
            // Buttons
            componentSection("Buttons") {
                VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
                    HStack(spacing: CarbonTheme.Spacing.spacing03) {
                        CarbonButton("Primary", type: .primary) { }
                        CarbonButton("Secondary", type: .secondary) { }
                        CarbonButton("Tertiary", type: .tertiary) { }
                    }
                    
                    HStack(spacing: CarbonTheme.Spacing.spacing03) {
                        CarbonButton("Ghost", type: .ghost) { }
                        CarbonButton("Danger", type: .danger) { }
                        CarbonButton("Disabled", isDisabled: true) { }
                    }
                }
            }
            
            // Text Fields
            componentSection("Text Fields") {
                VStack(spacing: CarbonTheme.Spacing.spacing04) {
                    CarbonTextField(
                        text: $textFieldValue,
                        placeholder: "Enter message",
                        label: "Message"
                    )
                    
                    CarbonTextField(
                        text: .constant(""),
                        placeholder: "Enter password",
                        label: "Password",
                        helperText: "Password must be at least 8 characters",
                        isSecure: true
                    )
                    
                    CarbonTextField(
                        text: .constant("Error text"),
                        placeholder: "Enter value",
                        label: "With Error",
                        errorText: "This field is required"
                    )
                }
            }
            
            // Progress Indicators
            componentSection("Progress Indicators") {
                VStack(spacing: CarbonTheme.Spacing.spacing04) {
                    CarbonProgressIndicator(
                        value: progressValue,
                        label: "Download Progress",
                        showPercentage: true
                    )
                    
                    CarbonProgressIndicator(
                        indeterminate: true,
                        label: "Loading..."
                    )
                    
                    HStack(spacing: CarbonTheme.Spacing.spacing05) {
                        CarbonProgressIndicator(
                            value: 75,
                            type: .circular,
                            size: .large
                        )
                        
                        CarbonProgressIndicator(
                            indeterminate: true,
                            type: .circular,
                            size: .medium
                        )
                    }
                }
            }
            
            // Notifications Demo
            componentSection("Notifications") {
                VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
                    HStack(spacing: CarbonTheme.Spacing.spacing03) {
                        CarbonButton("Info", type: .secondary, size: .small) {
                            notificationManager.show(type: .info, title: "Device Connected", message: "Successfully connected to LoRa device.")
                        }
                        
                        CarbonButton("Success", type: .secondary, size: .small) {
                            notificationManager.show(type: .success, title: "Message Sent", message: "Your encrypted message was delivered.")
                        }
                        
                        CarbonButton("Warning", type: .secondary, size: .small) {
                            notificationManager.show(type: .warning, title: "Weak Signal", message: "Signal strength is low.")
                        }
                        
                        CarbonButton("Error", type: .secondary, size: .small) {
                            notificationManager.show(type: .error, title: "Connection Failed", message: "Unable to connect to device.")
                        }
                    }
                    
                    CarbonButton("Show Modal", type: .tertiary) {
                        isModalPresented = true
                    }
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing05)
    }
    
    private func componentSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing04) {
            Text(title)
                .font(CarbonTheme.Typography.heading03)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            content()
                .padding(CarbonTheme.Spacing.spacing04)
                .background(CarbonTheme.ColorPalette.surface)
                .cornerRadius(CarbonTheme.BorderRadius.medium)
        }
    }
    
    // MARK: - Spacing Showcase
    
    private var spacingShowcase: some View {
        LazyVStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing06) {
            spacingSection("Spacing Scale", spacings: [
                ("Spacing 01", CarbonTheme.Spacing.spacing01),
                ("Spacing 02", CarbonTheme.Spacing.spacing02),
                ("Spacing 03", CarbonTheme.Spacing.spacing03),
                ("Spacing 04", CarbonTheme.Spacing.spacing04),
                ("Spacing 05", CarbonTheme.Spacing.spacing05),
                ("Spacing 06", CarbonTheme.Spacing.spacing06),
                ("Spacing 07", CarbonTheme.Spacing.spacing07),
                ("Spacing 08", CarbonTheme.Spacing.spacing08)
            ])
            
            spacingSection("Layout Sizes", spacings: [
                ("Size 01", CarbonTheme.Layout.size01),
                ("Size 02", CarbonTheme.Layout.size02),
                ("Size 03", CarbonTheme.Layout.size03),
                ("Size 04", CarbonTheme.Layout.size04),
                ("Size 05", CarbonTheme.Layout.size05),
                ("Size 06", CarbonTheme.Layout.size06),
                ("Size 07", CarbonTheme.Layout.size07),
                ("Size 08", CarbonTheme.Layout.size08)
            ])
        }
        .padding(CarbonTheme.Spacing.spacing05)
    }
    
    private func spacingSection(_ title: String, spacings: [(String, CGFloat)]) -> some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing04) {
            Text(title)
                .font(CarbonTheme.Typography.heading03)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
                ForEach(Array(spacings.enumerated()), id: \.offset) { _, spacing in
                    HStack(spacing: CarbonTheme.Spacing.spacing03) {
                        Rectangle()
                            .fill(CarbonTheme.ColorPalette.interactive)
                            .frame(width: spacing.1, height: 16)
                        
                        Text("\(spacing.0): \(Int(spacing.1))px")
                            .font(CarbonTheme.Typography.body01)
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                        
                        Spacer()
                    }
                    .padding(CarbonTheme.Spacing.spacing03)
                    .background(CarbonTheme.ColorPalette.surface)
                    .cornerRadius(CarbonTheme.BorderRadius.small)
                }
            }
        }
    }
    
    // MARK: - Modal Content
    
    private var modalContent: some View {
        CarbonModal(
            isPresented: $isModalPresented,
            title: "Device Connection",
            message: "This modal demonstrates the Carbon Design System modal component. You can use modals for confirmations, forms, or detailed information.",
            primaryAction: CarbonModal.ModalAction(title: "Connect", type: .primary) {
                notificationManager.show(type: .success, title: "Connected", message: "Device connected successfully!")
            },
            secondaryAction: CarbonModal.ModalAction(title: "Cancel", type: .secondary) {
                // Cancel action
            }
        )
    }
}

// MARK: - Preview

#Preview {
    CarbonShowcaseView()
        .frame(width: 800, height: 600)
}
