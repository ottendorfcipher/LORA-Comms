import SwiftUI
import CoreBluetooth

// MARK: - Enhanced Bluetooth Device View with Carbon Design System

struct BluetoothDeviceView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var notificationManager: CarbonNotificationManager
    @State private var showConnectionDetails = false
    @State private var selectedDevice: MeshtasticDevice?
    
    var body: some View {
        VStack(spacing: CarbonTheme.Spacing.spacing05) {
            // Header with Bluetooth status
            headerView
            
            // Connection progress
            if bluetoothManager.connectionProgress != .idle {
                connectionProgressView
            }
            
            // Error display
            if let error = bluetoothManager.lastError {
                errorView(error)
            }
            
            // Device list
            deviceListView
            
            Spacer()
        }
        .padding(CarbonTheme.Spacing.spacing05)
        .background(CarbonTheme.ColorPalette.background)
        .navigationTitle("Bluetooth Devices")
        .sheet(isPresented: $showConnectionDetails) {
            if let device = selectedDevice {
                BluetoothConnectionDetailView(
                    device: device,
                    bluetoothManager: bluetoothManager
                )
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            HStack {
                Text("Bluetooth Devices")
                    .font(CarbonTheme.Typography.heading03)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                
                Spacer()
                
                // Bluetooth state indicator
                HStack(spacing: CarbonTheme.Spacing.spacing02) {
                    Circle()
                        .fill(bluetoothStateColor)
                        .frame(width: 8, height: 8)
                    
                    Text(bluetoothManager.bluetoothState.description)
                        .font(CarbonTheme.Typography.caption01)
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                }
            }
            
            // Action buttons
            HStack(spacing: CarbonTheme.Spacing.spacing03) {
                CarbonButton(
                    bluetoothManager.isScanning ? "Stop Scan" : "Start Scan",
                    type: bluetoothManager.isScanning ? .secondary : .primary,
                    size: .medium
                ) {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                        notificationManager.show(
                            type: .info,
                            title: "Scanning Started",
                            message: "Looking for nearby Meshtastic devices..."
                        )
                    }
                }
                .disabled(bluetoothManager.bluetoothState != .poweredOn)
                
                if bluetoothManager.connectionState == .connected {
                    CarbonButton("Disconnect", type: .danger, size: .medium) {
                        bluetoothManager.disconnect()
                        notificationManager.show(
                            type: .info,
                            title: "Disconnected",
                            message: "Bluetooth device disconnected"
                        )
                    }
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Connection Progress View
    
    private var connectionProgressView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text("Connection Progress")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            HStack(spacing: CarbonTheme.Spacing.spacing03) {
                CarbonProgressIndicator(
                    indeterminate: true,
                    type: .circular,
                    size: .small
                )
                
                Text(bluetoothManager.connectionProgress.description)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
            }
            
            // Connection steps
            CarbonProgressSteps(
                steps: connectionSteps,
                currentStep: currentConnectionStep,
                orientation: .horizontal
            )
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: BluetoothManager.BluetoothError) -> some View {
        HStack(spacing: CarbonTheme.Spacing.spacing03) {
            CarbonTheme.Icons.error
                .foregroundColor(CarbonTheme.ColorPalette.error)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing01) {
                Text("Bluetooth Error")
                    .font(CarbonTheme.Typography.heading02)
                    .foregroundColor(CarbonTheme.ColorPalette.error)
                
                Text(error.description)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            }
            
            Spacer()
            
            CarbonButton("Retry", type: .secondary, size: .small) {
                bluetoothManager.startScanning()
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.error.opacity(0.1))
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Device List View
    
    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text("Discovered Devices (\(bluetoothManager.discoveredDevices.count))")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            if bluetoothManager.discoveredDevices.isEmpty {
                emptyDeviceListView
            } else {
                LazyVStack(spacing: CarbonTheme.Spacing.spacing02) {
                    ForEach(bluetoothManager.discoveredDevices) { device in
                        BluetoothDeviceRowView(
                            device: device,
                            bluetoothManager: bluetoothManager,
                            onDetailsTapped: {
                                selectedDevice = device
                                showConnectionDetails = true
                            }
                        )
                    }
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Empty Device List View
    
    private var emptyDeviceListView: some View {
        VStack(spacing: CarbonTheme.Spacing.spacing04) {
            CarbonTheme.Icons.bluetooth
                .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                .font(.system(size: 48))
            
            Text("No devices found")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            Text("Make sure your Meshtastic device is powered on and in pairing mode")
                .font(CarbonTheme.Typography.body01)
                .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(CarbonTheme.Spacing.spacing06)
    }
    
    // MARK: - Computed Properties
    
    private var bluetoothStateColor: Color {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return CarbonTheme.ColorPalette.success
        case .poweredOff:
            return CarbonTheme.ColorPalette.error
        case .unauthorized, .unsupported:
            return CarbonTheme.ColorPalette.warning
        default:
            return CarbonTheme.ColorPalette.textSecondary
        }
    }
    
    private var connectionSteps: [CarbonProgressSteps.StepModel] {
        [
            CarbonProgressSteps.StepModel(id: "scanning", title: "Scanning", description: "Looking for devices"),
            CarbonProgressSteps.StepModel(id: "connecting", title: "Connecting", description: "Establishing connection"),
            CarbonProgressSteps.StepModel(id: "services", title: "Services", description: "Discovering services"),
            CarbonProgressSteps.StepModel(id: "characteristics", title: "Setup", description: "Configuring communication"),
            CarbonProgressSteps.StepModel(id: "complete", title: "Ready", description: "Connection established")
        ]
    }
    
    private var currentConnectionStep: Int {
        switch bluetoothManager.connectionProgress {
        case .idle: return -1
        case .scanning: return 0
        case .connecting: return 1
        case .discoveringServices: return 2
        case .discoveringCharacteristics, .establishingConnection: return 3
        case .completed: return 4
        }
    }
}

// MARK: - Bluetooth Device Row View

struct BluetoothDeviceRowView: View {
    let device: MeshtasticDevice
    @ObservedObject var bluetoothManager: BluetoothManager
    let onDetailsTapped: () -> Void
    @EnvironmentObject var notificationManager: CarbonNotificationManager
    
    private var isConnected: Bool {
        bluetoothManager.connectionState == .connected &&
        bluetoothManager.connectedPeripheral?.identifier.uuidString == device.id
    }
    
    private var isConnecting: Bool {
        bluetoothManager.connectionState == .connecting
    }
    
    var body: some View {
        HStack(spacing: CarbonTheme.Spacing.spacing04) {
            // Device icon and signal strength
            VStack(spacing: CarbonTheme.Spacing.spacing01) {
                CarbonTheme.Icons.bluetooth
                    .foregroundColor(signalColor)
                    .font(.system(size: 20))
                
                // Signal strength bars
                signalStrengthIndicator
            }
            
            // Device information
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing01) {
                Text(device.name)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: CarbonTheme.Spacing.spacing02) {
                    Text("RSSI: \(device.rssi) dBm")
                        .font(CarbonTheme.Typography.caption01)
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                    
                    Text("•")
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                    
                    Text(device.signalQuality)
                        .font(CarbonTheme.Typography.caption01)
                        .foregroundColor(signalColor)
                }
                
                Text("Discovered \(timeAgo(device.discoveredAt))")
                    .font(CarbonTheme.Typography.caption01)
                    .foregroundColor(CarbonTheme.ColorPalette.textTertiary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: CarbonTheme.Spacing.spacing02) {
                if isConnected {
                    Text("Connected")
                        .font(CarbonTheme.Typography.caption01)
                        .foregroundColor(CarbonTheme.ColorPalette.success)
                    
                    CarbonButton("Disconnect", type: .danger, size: .small) {
                        bluetoothManager.disconnect()
                        notificationManager.show(
                            type: .info,
                            title: "Disconnected",
                            message: "Disconnected from \(device.name)"
                        )
                    }
                } else if isConnecting {
                    CarbonProgressIndicator(
                        indeterminate: true,
                        type: .circular,
                        size: .small
                    )
                } else {
                    CarbonButton("Connect", type: .primary, size: .small) {
                        bluetoothManager.connect(to: device)
                        notificationManager.show(
                            type: .info,
                            title: "Connecting",
                            message: "Connecting to \(device.name)..."
                        )
                    }
                }
                
                CarbonButton("Details", type: .ghost, size: .small) {
                    onDetailsTapped()
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(isConnected ? CarbonTheme.ColorPalette.success.opacity(0.1) : CarbonTheme.ColorPalette.background)
        .cornerRadius(CarbonTheme.BorderRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: CarbonTheme.BorderRadius.small)
                .stroke(
                    isConnected ? CarbonTheme.ColorPalette.success : CarbonTheme.ColorPalette.border,
                    lineWidth: isConnected ? 2 : 1
                )
        )
    }
    
    // MARK: - Signal Strength Indicator
    
    private var signalStrengthIndicator: some View {
        HStack(spacing: 1) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(index < signalBars ? signalColor : CarbonTheme.ColorPalette.surface)
                    .frame(width: 2, height: CGFloat(4 + index * 2))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var signalColor: Color {
        switch device.rssi {
        case -50...0:
            return CarbonTheme.ColorPalette.success
        case -60..<(-50):
            return CarbonTheme.ColorPalette.interactive
        case -70..<(-60):
            return CarbonTheme.ColorPalette.warning
        default:
            return CarbonTheme.ColorPalette.error
        }
    }
    
    private var signalBars: Int {
        switch device.rssi {
        case -50...0: return 4
        case -60..<(-50): return 3
        case -70..<(-60): return 2
        case -80..<(-70): return 1
        default: return 0
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else {
            return "\(Int(interval/3600))h ago"
        }
    }
}

// MARK: - Bluetooth Connection Detail View

struct BluetoothConnectionDetailView: View {
    let device: MeshtasticDevice
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing05) {
                    // Device Header
                    deviceHeaderView
                    
                    // Connection Information
                    connectionInfoView
                    
                    // Signal Information
                    signalInfoView
                    
                    // Technical Details
                    technicalDetailsView
                }
                .padding(CarbonTheme.Spacing.spacing05)
            }
            .background(CarbonTheme.ColorPalette.background)
            .navigationTitle("Device Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    return .navigationBarTrailing
                    #else
                    return .automatic
                    #endif
                }()) {
                    CarbonButton("Done", type: .primary, size: .small) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Device Header View
    
    private var deviceHeaderView: some View {
        HStack(spacing: CarbonTheme.Spacing.spacing04) {
            CarbonTheme.Icons.bluetooth
                .foregroundColor(CarbonTheme.ColorPalette.interactive)
                .font(.system(size: 48))
            
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing02) {
                Text(device.name)
                    .font(CarbonTheme.Typography.heading03)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                
                Text("Meshtastic Device")
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                
                HStack(spacing: CarbonTheme.Spacing.spacing02) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(bluetoothManager.connectionState.rawValue)
                        .font(CarbonTheme.Typography.caption01)
                        .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Connection Information View
    
    private var connectionInfoView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text("Connection Information")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            VStack(spacing: CarbonTheme.Spacing.spacing02) {
                DetailRow(label: "Device ID", value: device.id)
                DetailRow(label: "Connection State", value: bluetoothManager.connectionState.rawValue)
                DetailRow(label: "Progress", value: bluetoothManager.connectionProgress.description)
                
                if let lastPacketTime = bluetoothManager.lastPacketTime {
                    DetailRow(label: "Last Packet", value: formatDate(lastPacketTime))
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Signal Information View
    
    private var signalInfoView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text("Signal Information")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            VStack(spacing: CarbonTheme.Spacing.spacing02) {
                DetailRow(label: "RSSI", value: "\(device.rssi) dBm")
                DetailRow(label: "Signal Quality", value: device.signalQuality)
                
                if let currentRSSI = bluetoothManager.signalStrength {
                    DetailRow(label: "Current RSSI", value: "\(currentRSSI) dBm")
                }
                
                DetailRow(label: "Discovered", value: formatDate(device.discoveredAt))
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Technical Details View
    
    private var technicalDetailsView: some View {
        VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing03) {
            Text("Technical Details")
                .font(CarbonTheme.Typography.heading02)
                .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            
            VStack(spacing: CarbonTheme.Spacing.spacing02) {
                DetailRow(
                    label: "Service UUID",
                    value: BluetoothManager.meshtasticServiceUUID.uuidString
                )
                DetailRow(
                    label: "To Radio UUID",
                    value: BluetoothManager.toRadioCharacteristicUUID.uuidString
                )
                DetailRow(
                    label: "From Radio UUID",
                    value: BluetoothManager.fromRadioCharacteristicUUID.uuidString
                )
                DetailRow(
                    label: "From Num UUID",
                    value: BluetoothManager.fromNumCharacteristicUUID.uuidString
                )
            }
        }
        .padding(CarbonTheme.Spacing.spacing04)
        .background(CarbonTheme.ColorPalette.surface)
        .cornerRadius(CarbonTheme.BorderRadius.medium)
    }
    
    // MARK: - Helper Views
    
    private struct DetailRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                
                Spacer()
                
                Text(value)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return CarbonTheme.ColorPalette.success
        case .connecting:
            return CarbonTheme.ColorPalette.warning
        case .disconnected:
            return CarbonTheme.ColorPalette.textSecondary
        case .error:
            return CarbonTheme.ColorPalette.error
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Bluetooth Device View") {
    BluetoothDeviceView(bluetoothManager: BluetoothManager())
        .environmentObject(CarbonNotificationManager())
}

#Preview("Bluetooth Device Row") {
    // Create a mock device for preview
    let mockDevice = MeshtasticDevice(
        peripheral: nil,
        name: "Meshtastic Device",
        rssi: -65
    )
    
    return BluetoothDeviceRowView(
        device: mockDevice,
        bluetoothManager: BluetoothManager(),
        onDetailsTapped: {}
    )
    .environmentObject(CarbonNotificationManager())
    .padding()
    .background(CarbonTheme.ColorPalette.background)
}
