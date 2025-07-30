# LORA Comms - Carbon Design System Integration Plan

## 1. Overview

This document outlines the plan to redesign the LORA Comms application using IBM's Carbon Design System. The goal is to create a user interface that is modern, accessible, and aligned with macOS UX/UI best practices, while providing clear scaffolding for the application's technical features.

## 2. Core Principles

- **Clarity**: The interface will be clean, organized, and easy to understand.
- **Consistency**: All UI elements will follow the Carbon Design System guidelines.
- **Accessibility**: The app will be fully accessible, with support for VoiceOver, dynamic type, and high-contrast modes.
- **Progressive Disclosure**: Advanced features will be available but not overwhelming to new users.
- **Scaffolding**: The UI will guide users through complex tasks, such as connecting a new device or understanding the mesh network.

## 3. Design Language

### Color Palette (IBM Design Language V10)

- **Primary UI Background**: `gray100` (#161616)
- **Secondary UI Background**: `gray90` (#262626)
- **Interactive Elements**: `blue60` (#0043CE)
- **Text**: `gray10` (#F4F4F4) for primary text, `gray30` (#C6C6C6) for secondary text.
- **Status Indicators**: `green50` (Success), `yellow30` (Warning), `red60` (Error).

### Typography (IBM Plex)

- **Font**: IBM Plex Sans for all UI text.
- **Hierarchy**: A clear typographic scale will be used to differentiate between headings, body text, and labels.

### Iconography (Carbon Icons)

- **Icons**: All icons will be sourced from the Carbon Design System icon library to ensure consistency.

## 4. Component Library

A new set of SwiftUI views will be created to implement the Carbon components. These will be located in a new `CarbonSwiftUI` directory.

- `CarbonButton.swift`
- `CarbonTextField.swift`
- `CarbonSidebar.swift`
- `CarbonModal.swift`
- `CarbonNotification.swift`
- ... and others as needed.

## 5. UI Redesign Plan

### Main Window

- A three-pane layout will be used: a narrow icon-based sidebar for navigation, a primary content list (e.g., chats or devices), and a detail view.

### Connection Assistant

- A new guided flow will be created to help users connect a new device. This will include:
  - A choice between Serial/USB and Bluetooth.
  - A list of detected devices with clear status indicators.
  - Step-by-step instructions for troubleshooting connection issues.

### Mesh Network Visualizer

- A new view will be created to visualize the LoRa mesh network. This will include:
  - A graphical representation of the nodes in the mesh.
  - Signal strength indicators for each connection.
  - Visualization of message routing and hops.
  - An interactive map view showing the geographical location of nodes.

### Progressive Disclosure

- **Device Settings**: Basic device settings will be visible by default. Advanced settings (e.g., LoRa channel configuration) will be accessible via an "Advanced" button or a separate view.
- **Message Details**: A simple message view will be shown by default. Users can inspect a message to see detailed metadata (e.g., SNR, hop count, etc.).

## 6. Implementation Phases

1.  **Design System Foundation**: Create the `CARBON_DESIGN_SYSTEM.md` document and a `CarbonTheme.swift` file with the design tokens.
2.  **Component Library**: Build the core Carbon SwiftUI components.
3.  **Main UI Redesign**: Rebuild the main application views using the new Carbon components.
4.  **UX Enhancements**: Implement the Connection Assistant and Mesh Network Visualizer.
5.  **Accessibility Pass**: Thoroughly test and implement accessibility features.

