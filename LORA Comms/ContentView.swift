//
//  ContentView.swift
//  LORA Comms
//
//  Created by Nicholas Weiner on 7/28/25.
//

import SwiftUI

// MARK: - Main Content View with Carbon Design System

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var meshtasticManager: MeshtasticManager
    @StateObject private var notificationManager = CarbonNotificationManager()
    
    @State private var selectedSidebarItem: String? = "chats"
    @State private var isSidebarCollapsed = false
    
    init() {
        let deviceManager = DeviceManager()
        self._deviceManager = StateObject(wrappedValue: deviceManager)
        self._meshtasticManager = StateObject(wrappedValue: MeshtasticManager(deviceManager: deviceManager))
    }
    
    var body: some View {
        NavigationSplitView {
            CarbonSidebar(
                selectedItem: $selectedSidebarItem,
                items: sidebarItems,
                isCollapsed: isSidebarCollapsed,
                onToggleCollapse: {
                    isSidebarCollapsed.toggle()
                }
            )
        } content: {
            // Primary content list based on sidebar selection
            switch selectedSidebarItem {
            case "chats":
                ChatListView(meshtasticManager: meshtasticManager)
            case "devices":
                DeviceListView(deviceManager: deviceManager)
            case "network":
                NetworkVisualizerView(meshtasticManager: meshtasticManager)
            case "carbon-showcase":
                CarbonShowcaseView()
            default:
                VStack(spacing: CarbonTheme.Spacing.spacing04) {
                    CarbonTheme.Icons.home
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                        .font(.system(size: 48))
                    
                    Text("Welcome to LORA Comms")
                        .font(CarbonTheme.Typography.heading03)
                        .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    
                    Text("Select a section from the sidebar to get started")
                        .font(CarbonTheme.Typography.body01)
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CarbonTheme.ColorPalette.background)
            }
        } detail: {
            // Detail view based on primary content selection
            switch selectedSidebarItem {
            case "chats":
                ChatDetailView(meshtasticManager: meshtasticManager)
            case "devices":
                DeviceDetailView(deviceManager: deviceManager)
            case "network":
                Text("Select a node to view details")
                    .foregroundColor(themeManager.theme.textSecondaryColor)
                    .font(themeManager.theme.font)
            default:
                Text("Select an item")
                    .foregroundColor(themeManager.theme.textSecondaryColor)
                    .font(themeManager.theme.font)
            }
        }
        .navigationTitle("LORA Comms")
        .background(CarbonTheme.ColorPalette.background)
        .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
        .carbonNotifications(manager: notificationManager)
        .environmentObject(notificationManager)
    }
    
    private var sidebarItems: [SidebarItem] {
        [
            SidebarItem(id: "chats", title: "Chats", icon: "message", badge: "3"),
            SidebarItem(id: "devices", title: "Devices", icon: "antenna.radiowaves.left.and.right"),
            SidebarItem(id: "network", title: "Network", icon: "network"),
            SidebarItem(id: "settings", title: "Settings", icon: "gear"),
            SidebarItem(id: "carbon-showcase", title: "Design System", icon: "paintbrush")
        ]
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}
