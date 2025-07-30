import SwiftUI

// MARK: - Device List View

struct DeviceListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceManager: DeviceManager
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingConnectionAssistant = false
    @State private var selectedDevice: DeviceInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Connection Status
            connectionStatusView
            
            // Device List
            if deviceManager.availableDevices.isEmpty && !deviceManager.isScanning {
                emptyStateView
            } else {
                deviceListView
            }
        }
        .background(themeManager.theme.backgroundColor)
        .sheet(isPresented: $showingConnectionAssistant) {
            ConnectionAssistantView(
                deviceManager: deviceManager,
                bluetoothManager: bluetoothManager
            )
        }
        .onAppear {
            Task {
                await deviceManager.scanDevices()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Devices")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            HStack(spacing: 8) {
                CarbonButton("Refresh", type: .ghost, size: .small) {
                    Task {
                        await deviceManager.scanDevices()
                    }
                }
                
                CarbonButton("Connect", type: .primary, size: .small) {
                    showingConnectionAssistant = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Connection Status View
    
    private var connectionStatusView: some View {
        VStack(spacing: 8) {
            if let connectedDevice = deviceManager.connectedDevice {
                HStack(spacing: 12) {
                    Circle()
                        .fill(themeManager.theme.successColor)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected to \(connectedDevice.name)")
                            .font(themeManager.theme.font)
                            .foregroundColor(themeManager.theme.textColor)
                        
                        if let manufacturer = connectedDevice.manufacturer {
                            Text(manufacturer)
                                .font(themeManager.theme.font)
                                .foregroundColor(themeManager.theme.textSecondaryColor)
                        }
                    }
                    
                    Spacer()
                    
                    CarbonButton("Disconnect", type: .danger, size: .small) {
                        deviceManager.disconnectDevice(connectedDevice)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.theme.surfaceColor)
            } else {
                HStack(spacing: 12) {
                    Circle()
                        .fill(themeManager.theme.errorColor)
                        .frame(width: 8, height: 8)
                    
                    Text("No device connected")
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.theme.surfaceColor)
            }
        }
    }
    
    // MARK: - Device List View
    
    private var deviceListView: some View {
        List(selection: $selectedDevice) {
            if deviceManager.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for devices...")
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(deviceManager.availableDevices, id: \.id) { device in
                DeviceRowView(device: device, deviceManager: deviceManager)
                    .tag(device)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(themeManager.theme.textSecondaryColor)
            
            Text("No devices found")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Text("Connect a LoRa device via USB or Bluetooth to get started")
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textSecondaryColor)
                .multilineTextAlignment(.center)
            
            CarbonButton("Connect Device", type: .primary) {
                showingConnectionAssistant = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let device: DeviceInfo
    @ObservedObject var deviceManager: DeviceManager
    @State private var isConnecting = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Device Type Icon
            Image(systemName: device.deviceType.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(deviceTypeColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // Device Name
                Text(device.name)
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textColor)
                    .lineLimit(1)
                
                // Device Type and Manufacturer
                HStack(spacing: 8) {
                    Text(device.deviceType.displayName)
                        .font(themeManager.theme.font)
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                    
                    if let manufacturer = device.manufacturer {
                        Text("•")
                            .foregroundColor(themeManager.theme.textSecondaryColor)
                        
                        Text(manufacturer)
                            .font(themeManager.theme.font)
                            .foregroundColor(themeManager.theme.textSecondaryColor)
                    }
                }
                
                // Device Path (for debugging)
                Text(device.path)
                    .font(.system(size: 10).monospaced())
                    .foregroundColor(themeManager.theme.textSecondaryColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Connection Status and Actions
            VStack(alignment: .trailing, spacing: 4) {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if deviceManager.connectedDevice?.id == device.id {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Connected")
                            .font(themeManager.theme.font)
                            .foregroundColor(themeManager.theme.successColor)
                        
                        CarbonButton("Disconnect", type: .danger, size: .small) {
                            deviceManager.disconnectDevice(device)
                        }
                    }
                } else {
                    CarbonButton("Connect", type: .primary, size: .small) {
                        connectToDevice()
                    }
                    .disabled(!device.isAvailable)
                }
                
                // Availability Indicator
                Circle()
                    .fill(device.isAvailable ? themeManager.theme.successColor : themeManager.theme.textSecondaryColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
        .accessibilityLabel("\(device.name) \(device.deviceType.displayName) device")
        .accessibilityValue(deviceManager.connectedDevice?.id == device.id ? "Connected" : "Available")
    }
    
    private var deviceTypeColor: Color {
        switch device.deviceType {
        case .serial:
            return themeManager.theme.interactiveColor
        case .bluetooth:
            return themeManager.theme.successColor
        case .tcp:
            return themeManager.theme.warningColor
        }
    }
    
    private func connectToDevice() {
        isConnecting = true
        Task {
            let success = await deviceManager.connectDevice(device)
            isConnecting = false
            if success {
                await deviceManager.getNodes()
            }
        }
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceManager: DeviceManager
    
    var body: some View {
        if let connectedDevice = deviceManager.connectedDevice {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Device Info Section
                    deviceInfoSection(for: connectedDevice)
                    
                    // Nodes Section
                    nodesSection
                    
                    // Statistics Section
                    statisticsSection
                    
                    // Actions Section
                    actionsSection
                }
                .padding(16)
            }
            .background(themeManager.theme.backgroundColor)
        } else {
            // No Device Selected
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 48))
                    .foregroundColor(themeManager.theme.textSecondaryColor)
                
                Text("No device connected")
                    .font(themeManager.theme.fontHeading)
                    .foregroundColor(themeManager.theme.textColor)
                
                Text("Connect a device to view its details")
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textSecondaryColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.backgroundColor)
        }
    }
    
    // MARK: - Device Info Section
    
    private func deviceInfoSection(for device: DeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            VStack(spacing: 8) {
                DeviceDetailRow(label: "Name", value: device.name)
                DeviceDetailRow(label: "Type", value: device.deviceType.displayName)
                DeviceDetailRow(label: "Path", value: device.path)
                
                if let manufacturer = device.manufacturer {
                    DeviceDetailRow(label: "Manufacturer", value: manufacturer)
                }
                
                if let vendorId = device.vendorId {
                    DeviceDetailRow(label: "Vendor ID", value: vendorId)
                }
                
                if let productId = device.productId {
                    DeviceDetailRow(label: "Product ID", value: productId)
                }
            }
        }
        .padding(16)
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Nodes Section
    
    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mesh Nodes (\(deviceManager.nodes.count))")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            if deviceManager.nodes.isEmpty {
                Text("No nodes discovered yet")
                    .font(themeManager.theme.font)
                    .foregroundColor(themeManager.theme.textSecondaryColor)
            } else {
                VStack(spacing: 8) {
                    ForEach(deviceManager.nodes, id: \.id) { node in
                        NodeDetailRow(node: node)
                    }
                }
            }
            
            CarbonButton("Refresh Nodes", type: .secondary, size: .small) {
                Task {
                    await deviceManager.getNodes()
                }
            }
        }
        .padding(16)
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            VStack(spacing: 8) {
                DeviceDetailRow(label: "Messages Sent", value: "\(deviceManager.messages.filter { $0.isFromMe }.count)")
                DeviceDetailRow(label: "Messages Received", value: "\(deviceManager.messages.filter { !$0.isFromMe }.count)")
                DeviceDetailRow(label: "Cache Status", value: deviceManager.isCacheConnected ? "Connected" : "Disconnected")
            }
        }
        .padding(16)
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            VStack(spacing: 8) {
                CarbonButton("Clear Message History", type: .secondary) {
                    // Clear message history
                }
                
                CarbonButton("Clear Cache", type: .secondary) {
                    Task {
                        await deviceManager.clearCache()
                    }
                }
                
                CarbonButton("Disconnect Device", type: .danger) {
                    if let device = deviceManager.connectedDevice {
                        deviceManager.disconnectDevice(device)
                    }
                }
            }
        }
        .padding(16)
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Helper Views

struct DeviceDetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textSecondaryColor)
            
            Spacer()
            
            Text(value)
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textColor)
        }
    }
    
    init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    init(label: String, value: Date, style: Text.DateStyle) {
        self.label = label
        self.value = value.formatted(date: .abbreviated, time: .shortened)
    }
}

struct NodeDetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let node: NodeInfo
    
    var body: some View {
        HStack {
            Circle()
                .fill(node.isOnline ? themeManager.theme.successColor : themeManager.theme.textSecondaryColor)
                .frame(width: 6, height: 6)
            
            Text(node.name)
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            Text(node.shortName)
                .font(.system(size: 10).monospaced())
                .foregroundColor(themeManager.theme.textSecondaryColor)
        }
    }
}

