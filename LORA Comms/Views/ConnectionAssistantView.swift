import SwiftUI

// MARK: - Connection Assistant View

struct ConnectionAssistantView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedConnectionType: DeviceType = .serial
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            VStack(spacing: 24) {
                // Connection Type Picker
                connectionTypePicker
                
                // Device List
                deviceListView
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .padding(24)
        }
        .frame(width: 500, height: 400)
        .background(themeManager.theme.backgroundColor)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Connection Assistant")
                .font(themeManager.theme.fontHeading)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            CarbonButton("×", type: .ghost, size: .small) {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.theme.surfaceColor)
    }
    
    // MARK: - Connection Type Picker
    
    private var connectionTypePicker: some View {
        HStack(spacing: 8) {
            ForEach([DeviceType.serial, DeviceType.bluetooth], id: \.self) { type in
                CarbonButton(
                    type.displayName,
                    type: selectedConnectionType == type ? .primary : .secondary,
                    size: .medium
                ) {
                    selectedConnectionType = type
                    // Trigger a scan for the selected type
                    if type == .bluetooth {
                        bluetoothManager.startScanning()
                    } else {
                        Task { await deviceManager.scanDevices() }
                    }
                }
            }
        }
    }
    
    // MARK: - Device List View
    
    @ViewBuilder
    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Devices")
                .font(themeManager.theme.font)
                .foregroundColor(themeManager.theme.textSecondaryColor)
            
            if selectedConnectionType == .serial {
                if deviceManager.isScanning {
                    ProgressView()
                } else if deviceManager.availableDevices.isEmpty {
                    Text("No serial devices found. Ensure your device is connected.")
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                } else {
                    List(deviceManager.availableDevices, id: \.id) { device in
                        DeviceConnectionRow(device: device, deviceManager: deviceManager)
                    }
                    .listStyle(.plain)
                }
            } else {
                if bluetoothManager.isScanning {
                    VStack(spacing: CarbonTheme.Spacing.spacing03) {
                        CarbonProgressIndicator(
                            indeterminate: true,
                            type: .circular,
                            size: .medium,
                            label: "Scanning for devices..."
                        )
                        
                        Text("Looking for nearby Meshtastic devices")
                            .font(CarbonTheme.Typography.body01)
                            .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                    }
                } else if bluetoothManager.discoveredDevices.isEmpty {
                    VStack(spacing: CarbonTheme.Spacing.spacing03) {
                        CarbonTheme.Icons.bluetooth
                            .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                            .font(.system(size: 32))
                        
                        Text("No Bluetooth devices found")
                            .font(CarbonTheme.Typography.body01)
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                        
                        Text("Ensure your device is on and discoverable")
                            .font(CarbonTheme.Typography.caption01)
                            .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: CarbonTheme.Spacing.spacing02) {
                            ForEach(bluetoothManager.discoveredDevices, id: \.id) { device in
                                EnhancedBluetoothDeviceRow(
                                    device: device, 
                                    bluetoothManager: bluetoothManager
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack {
            CarbonButton("Refresh", type: .secondary) {
                if selectedConnectionType == .bluetooth {
                    bluetoothManager.startScanning()
                } else {
                    Task { await deviceManager.scanDevices() }
                }
            }
            
            Spacer()
            
            CarbonButton("Close", type: .primary) {
                dismiss()
            }
        }
    }
}

// MARK: - Device Row Views

struct DeviceConnectionRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let device: DeviceInfo
    @ObservedObject var deviceManager: DeviceManager
    
    var body: some View {
        HStack {
            Image(systemName: device.deviceType.iconName)
                .foregroundColor(themeManager.theme.textColor)
            
            Text(device.name)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            if deviceManager.connectedDevice?.id == device.id {
                Text("Connected")
                    .foregroundColor(themeManager.theme.successColor)
            } else {
                CarbonButton("Connect", type: .tertiary, size: .small) {
                    Task { await deviceManager.connectDevice(device) }
                }
            }
        }
    }
}

struct BluetoothDeviceRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let device: MeshtasticDevice
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        HStack {
            Image(systemName: "bluetooth")
                .foregroundColor(themeManager.theme.textColor)
            
            Text(device.name)
                .foregroundColor(themeManager.theme.textColor)
            
            Spacer()
            
            if bluetoothManager.connectionState == .connected {
                 Text("Connected")
                     .foregroundColor(themeManager.theme.successColor)
            } else {
                 CarbonButton("Connect", type: .tertiary, size: .small) {
                     bluetoothManager.connect(to: device)
                 }
            }
        }
    }
}

// MARK: - Enhanced Bluetooth Device Row for Connection Assistant

struct EnhancedBluetoothDeviceRow: View {
    let device: MeshtasticDevice
    @ObservedObject var bluetoothManager: BluetoothManager
    
    private var isConnected: Bool {
        bluetoothManager.connectionState == .connected &&
        bluetoothManager.connectedPeripheral?.identifier.uuidString == device.id
    }
    
    private var isConnecting: Bool {
        bluetoothManager.connectionState == .connecting
    }
    
    var body: some View {
        HStack(spacing: CarbonTheme.Spacing.spacing03) {
            // Bluetooth icon with signal strength indicator
            VStack(spacing: CarbonTheme.Spacing.spacing01) {
                CarbonTheme.Icons.bluetooth
                    .foregroundColor(signalColor)
                    .font(.system(size: 16))
                
                // Mini signal strength bars
                HStack(spacing: 1) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(index < signalBars ? signalColor : CarbonTheme.ColorPalette.surface)
                            .frame(width: 2, height: CGFloat(3 + index))
                    }
                }
            }
            
            // Device info
            VStack(alignment: .leading, spacing: CarbonTheme.Spacing.spacing01) {
                Text(device.name)
                    .font(CarbonTheme.Typography.body01)
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    .lineLimit(1)
                
                Text("\(device.rssi) dBm • \(device.signalQuality)")
                    .font(CarbonTheme.Typography.caption01)
                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
            }
            
            Spacer()
            
            // Connection button
            if isConnected {
                Text("Connected")
                    .font(CarbonTheme.Typography.caption01)
                    .foregroundColor(CarbonTheme.ColorPalette.success)
            } else if isConnecting {
                CarbonProgressIndicator(
                    indeterminate: true,
                    type: .circular,
                    size: .small
                )
            } else {
                CarbonButton("Connect", type: .primary, size: .small) {
                    bluetoothManager.connect(to: device)
                }
            }
        }
        .padding(CarbonTheme.Spacing.spacing03)
        .background(
            isConnected ? CarbonTheme.ColorPalette.success.opacity(0.1) : CarbonTheme.ColorPalette.background
        )
        .cornerRadius(CarbonTheme.BorderRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: CarbonTheme.BorderRadius.small)
                .stroke(
                    isConnected ? CarbonTheme.ColorPalette.success : CarbonTheme.ColorPalette.border.opacity(0.5),
                    lineWidth: 1
                )
        )
    }
    
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
        case -50...0: return 3
        case -60..<(-50): return 2
        case -70..<(-60): return 1
        default: return 0
        }
    }
}

