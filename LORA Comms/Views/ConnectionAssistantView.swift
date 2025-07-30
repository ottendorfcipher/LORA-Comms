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
                    ProgressView()
                } else if bluetoothManager.discoveredDevices.isEmpty {
                    Text("No Bluetooth devices found. Ensure your device is on and discoverable.")
                        .foregroundColor(themeManager.theme.textSecondaryColor)
                } else {
                    List(bluetoothManager.discoveredDevices, id: \.id) { device in
                        BluetoothDeviceRow(device: device, bluetoothManager: bluetoothManager)
                    }
                    .listStyle(.plain)
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

