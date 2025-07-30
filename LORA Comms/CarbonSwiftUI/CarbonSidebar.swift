import SwiftUI

// MARK: - Carbon Sidebar Component

public struct CarbonSidebar: View {
    // MARK: - Properties
    
    @Binding private var selectedItem: String?
    private let items: [SidebarItem]
    private let isCollapsed: Bool
    private let onToggleCollapse: () -> Void
    
    // MARK: - Initializer
    
    public init(
        selectedItem: Binding<String?>,
        items: [SidebarItem],
        isCollapsed: Bool = false,
        onToggleCollapse: @escaping () -> Void
    ) {
        self._selectedItem = selectedItem
        self.items = items
        self.isCollapsed = isCollapsed
        self.onToggleCollapse = onToggleCollapse
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with toggle button
            HStack {
                if !isCollapsed {
                    Text("Navigation")
                        .font(CarbonTheme.Typography.plexSans(size: 14, weight: .medium))
                        .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                }
                
                Spacer()
                
                Button(action: onToggleCollapse) {
                    Image(systemName: isCollapsed ? "sidebar.left" : "sidebar.leading")
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CarbonTheme.ColorPalette.surface)
            
            // Navigation Items
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items, id: \.id) { item in
                        SidebarItemView(
                            item: item,
                            isSelected: selectedItem == item.id,
                            isCollapsed: isCollapsed,
                            onTap: {
                                selectedItem = item.id
                            }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: isCollapsed ? 48 : 240)
        .background(CarbonTheme.ColorPalette.background)
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
    }
}

// MARK: - Sidebar Item Model

public struct SidebarItem {
    public let id: String
    public let title: String
    public let icon: String
    public let badge: String?
    public let children: [SidebarItem]?
    
    public init(
        id: String,
        title: String,
        icon: String,
        badge: String? = nil,
        children: [SidebarItem]? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.badge = badge
        self.children = children
    }
}

// MARK: - Sidebar Item View

private struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    let isCollapsed: Bool
    let onTap: () -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Item
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: item.icon)
                        .foregroundColor(isSelected ? CarbonTheme.ColorPalette.interactive : CarbonTheme.ColorPalette.textPrimary)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 16, height: 16)
                    
                    if !isCollapsed {
                        // Title
                        Text(item.title)
                            .font(CarbonTheme.Typography.plexSans(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? CarbonTheme.ColorPalette.interactive : CarbonTheme.ColorPalette.textPrimary)
                        
                        Spacer()
                        
                        // Badge
                        if let badge = item.badge {
                            Text(badge)
                                .font(CarbonTheme.Typography.plexSans(size: 10, weight: .medium))
                                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(CarbonTheme.ColorPalette.interactive)
                                )
                        }
                        
                        // Expand/Collapse indicator for items with children
                        if item.children != nil {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                Rectangle()
                    .fill(isSelected ? CarbonTheme.ColorPalette.surface : Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(isSelected ? CarbonTheme.ColorPalette.interactive : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )
            .accessibilityLabel(item.title)
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityHint(item.badge != nil ? "Badge: \(item.badge!)" : "")
            
            // Child Items (if expanded)
            if !isCollapsed, isExpanded, let children = item.children {
                ForEach(children, id: \.id) { child in
                    SidebarItemView(
                        item: child,
                        isSelected: false, // Child selection logic would go here
                        isCollapsed: false,
                        onTap: { /* Child tap logic */ }
                    )
                    .padding(.leading, 16)
                }
            }
        }
        .onTapGesture {
            if item.children != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    CarbonSidebar(
        selectedItem: .constant("chats"),
        items: [
            SidebarItem(id: "chats", title: "Chats", icon: "message", badge: "3"),
            SidebarItem(id: "devices", title: "Devices", icon: "antenna.radiowaves.left.and.right"),
            SidebarItem(id: "network", title: "Network", icon: "network"),
            SidebarItem(
                id: "settings",
                title: "Settings",
                icon: "gear",
                children: [
                    SidebarItem(id: "general", title: "General", icon: "gear"),
                    SidebarItem(id: "notifications", title: "Notifications", icon: "bell")
                ]
            )
        ],
        onToggleCollapse: { }
    )
    .frame(height: 400)
    .background(CarbonTheme.ColorPalette.background)
}
