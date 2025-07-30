import SwiftUI

// MARK: - Network Visualizer View

struct NetworkVisualizerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Network Graph
            if meshtasticManager.meshNetwork.profiles.isEmpty {
                emptyStateView
            } else {
                networkGraphView
            }
        }
        .background(themeManager.theme.backgroundColor)
        .onAppear {
            Task {
                await meshtasticManager.discoverNearbyNodes()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Network Topology")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            CarbonButton("Refresh", type: .ghost, size: .small) {
                Task {
                    await meshtasticManager.discoverNearbyNodes()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Network Graph View
    
    private var networkGraphView: some View {
        // A real implementation would use a proper graph drawing library
        // For now, this is a simplified representation
        ScrollView([.horizontal, .vertical]) {
            ZStack {
                // Connections
                ForEach(meshtasticManager.meshNetwork.topology.connections, id: \.id) { connection in
                    if let fromNode = meshtasticManager.meshNetwork.profiles.first(where: { $0.id == connection.fromNodeId }),
                       let toNode = meshtasticManager.meshNetwork.profiles.first(where: { $0.id == connection.toNodeId }) {
                        
                        Line(from: nodePosition(for: fromNode), to: nodePosition(for: toNode))
                            .stroke(Color.gray, lineWidth: 1)
                    }
                }
                
                // Nodes
                ForEach(meshtasticManager.meshNetwork.profiles, id: \.id) { profile in
                    NodeView(profile: profile)
                        .position(nodePosition(for: profile))
                }
            }
            .frame(width: 1000, height: 1000) // Example size
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(themeManager.theme.textSecondaryColor)
            
            Text("No network discovered")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Text("Connect a device and discover nearby nodes to see the network topology")
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textSecondaryColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func nodePosition(for profile: DeviceProfile) -> CGPoint {
        // This is a placeholder for a real graph layout algorithm
        let hash = profile.id.hashValue
        let x = CGFloat(abs(hash % 1000))
        let y = CGFloat(abs((hash / 1000) % 1000))
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Node View

struct NodeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let profile: DeviceProfile
    
    var body: some View {
        VStack {
            Image(systemName: profile.role.icon)
                .font(.system(size: 24))
                .foregroundColor(profile.isOnline ? themeManager.theme.interactiveColor : themeManager.theme.textSecondaryColor)
            
            Text(profile.shortName)
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textColor)
        }
        .padding(8)
        .background(
            Circle()
                .fill(themeManager.theme.surfaceColor)
                .overlay(
                    Circle()
                        .stroke(profile.isOnline ? themeManager.theme.successColor : themeManager.theme.textSecondaryColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - Line Shape

struct Line: Shape {
    var from: CGPoint
    var to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: from)
            p.addLine(to: to)
        }
    }
}
