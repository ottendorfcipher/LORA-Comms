# LORA macOS/iOS Communications App

🚧 **Project Status: Active Development** 🚧

A native Swift/Rust application rewrite of the original Electron-based meshtastic-macos-client, providing communication with Meshtastic/LoRa devices on macOS and iOS.

> **Note**: This project is currently under active development. Core functionality is working but some features are still being implemented. See the [Development Status](#development-status) section below for current progress.

## Project Overview

This project is a complete rewrite of the JavaScript/Electron meshtastic-macos-client into a native Swift/Rust application architecture. The original project used:
- **Frontend**: React/TypeScript with Electron
- **Backend**: Node.js with direct CLI calls to meshtastic
- **UI Framework**: Electron with web technologies

The new architecture uses:
- **Frontend**: SwiftUI for both macOS and iOS
- **Core Logic**: Rust library with async device communication
- **Bridge**: C FFI for Swift-Rust interoperability
- **Packaging**: Native macOS app bundle and iOS app

## Architecture

### Core Components

- **Swift Layer**: Native macOS/iOS UI using SwiftUI
- **Rust Core**: Low-level device communication and protocol handling
- **FFI Bridge**: C interface between Swift and Rust
- **Shared Models**: Common data structures across platforms

### Key Advantages

- **Performance**: Native code execution vs. JavaScript interpretation
- **Memory Efficiency**: No Chromium engine overhead
- **iOS Support**: Can run natively on iOS devices
- **System Integration**: Better macOS/iOS system integration
- **Security**: No web security concerns

## Features

### ✅ Implemented
- Native macOS application with SwiftUI interface
- Serial/USB device connectivity
- Real-time messaging interface
- Device discovery and management
- Message encryption (AES-256) with macOS Keychain integration
- Redis caching layer for performance optimization
- Mesh network topology visualization
- Cross-platform shared Rust core logic

### ✅ Recently Completed
- **Comprehensive Carbon Design System Integration**
  - Complete IBM Carbon Design System color palette with semantic tokens
  - Full typography scale (Display, Headings, Body, Captions, Code)
  - Spacing and layout tokens for consistent design
  - Shadow and animation duration tokens
  - Comprehensive icon library mapped to SF Symbols

- **Carbon SwiftUI Component Library**
  - CarbonButton with all 5 button types (Primary, Secondary, Tertiary, Ghost, Danger)
  - CarbonTextField with labels, validation, and accessibility
  - CarbonSidebar with collapsible navigation and badges
  - CarbonModal for dialogs and confirmations
  - CarbonNotification system with toast notifications
  - CarbonProgressIndicator (linear and circular, determinate and indeterminate)
  - CarbonProgressSteps for multi-step workflows

- **Design System Showcase**
  - Interactive design system documentation and component showcase
  - Live examples of all colors, typography, components, and spacing
  - Accessible via "Design System" in the sidebar

### ✅ Recently Completed
- **Enhanced CoreBluetooth Integration**
  - Comprehensive Bluetooth Low Energy (BLE) support for Meshtastic devices
  - Real-time connection progress tracking with visual indicators
  - Signal strength monitoring (RSSI) with quality assessment
  - Automatic device discovery and reconnection capabilities
  - Connection error handling with user-friendly error messages
  - Multi-step connection process visualization

- **Advanced Bluetooth UI Components**
  - Carbon Design System integrated Bluetooth device views
  - Enhanced device connection assistant with progress tracking
  - Signal strength indicators with visual bars and color coding
  - Detailed device information and technical specifications view
  - Connection status monitoring with real-time updates
  - Interactive device discovery with filtering and sorting

### 🚧 In Development
- Advanced radio settings (SF, BW, TX Power)
- Message delivery acknowledgments and retry logic
- Full Meshtastic protocol compliance
- RFCOMM support for legacy Bluetooth devices

### 📋 Planned
- Native iOS application
- TCP/IP device connectivity
- File transfer capabilities
- GPS integration for position messages
- Mesh routing optimization

## Project Structure

```
LORA-macOS-iOS-Comms/
├── Core/                   # Rust core library
│   ├── src/
│   │   ├── lib.rs         # Main library interface
│   │   ├── device/        # Device communication
│   │   ├── protocol/      # Meshtastic protocol handling
│   │   └── bridge/        # Swift-Rust bridge
├── macOS/                 # macOS Swift application
│   ├── LORA_macOS/
│   │   ├── ContentView.swift
│   │   ├── DeviceManager.swift
│   │   └── MessageView.swift
├── iOS/                   # iOS Swift application
│   ├── LORA_iOS/
│   │   ├── ContentView.swift
│   │   ├── DeviceManager.swift
│   │   └── MessageView.swift
└── Shared/                # Shared Swift code
    ├── Models/
    ├── ViewModels/
    └── Utilities/
```

## Building

### Prerequisites

- Xcode 15+
- Rust 1.70+
- Swift 5.9+

### Build Instructions

1. Build the Rust core library:
   ```bash
   cd Core
   cargo build --release
   ```

2. Open the Xcode workspace and build the macOS/iOS targets.

## Development Status

### Current Progress

This project is actively being developed with the following components completed:

- **Core Infrastructure**: ✅
  - Swift/Rust FFI bridge working
  - macOS app bundle with proper code signing
  - Redis caching integration for performance
  
- **Device Communication**: ✅
  - Serial device detection and connection
  - Basic Meshtastic protocol support
  - Message sending and receiving
  
- **Security**: ✅
  - AES-256 message encryption
  - macOS Keychain integration for key storage
  - Secure message display

- **User Interface**: ✅
  - SwiftUI-based chat interface
  - Device management views
  - Message history with encryption indicators

### Next Steps

1. **Theming System**: Implement centralized IBM Carbon Design-inspired theme manager
2. **Bluetooth Support**: Add CoreBluetooth integration for wireless devices
3. **Protocol Enhancement**: Complete Meshtastic protobuf implementation
4. **Advanced Features**: Radio settings, message acknowledgments, file transfer

### Contributing

This project is currently in active development. If you're interested in contributing:

1. Check the open issues for tasks that need help
2. Review the `MESHTASTIC_INTEGRATION_PLAN.md` for technical details
3. Follow the build instructions above to set up your development environment

### Known Issues

- Bluetooth connectivity is not yet implemented
- Some Meshtastic protocol features are still in development
- iOS version is planned but not yet started

## License

MIT License
