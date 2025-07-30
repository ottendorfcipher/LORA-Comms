# Project: LoRa Messaging App (macOS, Carbon Design, Swift + Rust)

## 🧭 Overview

Build a macOS-native messaging application styled using **IBM’s Carbon Design System**, offering offline peer-to-peer communication via **LoRa** using both **USB Serial** and **Bluetooth (BLE and RFCOMM)**. The app should resemble **iMessages in UX clarity**, while offering **advanced radio settings, AES-128 encryption**, and a **centralized style manager** for full visual theming control.

---

## 🧩 Architecture Summary

| Layer         | Technology                        |
|---------------|------------------------------------|
| UI            | SwiftUI (macOS native)             |
| Design System | IBM Carbon Design System           |
| Style System  | `ThemeManager` (centralized)       |
| Backend Logic | Rust (serial, Bluetooth, crypto)   |
| Communication | LoRa via UART & Bluetooth          |
| Encryption    | AES-128 (CBC or GCM)               |
| Storage       | SQLite or CoreData                 |
| Key Storage   | macOS Keychain                     |

---

## 🧠 User Flow Summary

1. **First Launch**
   - App auto-detects LoRa device via Serial or Bluetooth
   - Prompts user to name their device
   - AES key generated and stored in Keychain

2. **Chat Interface**
   - Sidebar: known nodes / devices
   - Main: encrypted message threads with status + signal metrics
   - Footer: message composer and encryption toggle

3. **Settings**
   - Radio tuning (frequency, power, SF, etc.)
   - Encryption keys (export/import/reset)
   - Bluetooth/Serial preference
   - Style customization panel

---

## 🔒 Encryption Features

- AES-128 encryption using CBC or GCM mode
- IV generated per message
- Message payload encrypted before transmission
- Lock icon (`🔒`) shown for encrypted messages
- Keys are generated and stored in **macOS Keychain**:
    - Use Swift KeychainAccess or native APIs
- Key mismatch triggers decryption failure toast
- Keys can be exported, imported, or regenerated

---

## 🔌 Communication Stack

### Serial
- Use `serialport` crate in Rust
- Autodetect USB LoRa devices (`/dev/cu.*`)
- Send/receive packets in structured format

### Bluetooth
- Use `btleplug` or macOS Bluetooth stack
- Support both:
    - BLE advertisement + GATT characteristics
    - RFCOMM socket-like connection
- Preference saved in app settings

---

## 🧱 Message Format

Encrypted messages must follow this JSON format:

```json
{
  "from": "node_alpha",
  "to": "node_bravo",
  "payload": "BASE64_ENCRYPTED_TEXT",
  "encrypted": true,
  "iv": "BASE64_IV",
  "timestamp": "2025-07-30T14:01:00Z",
  "ack_required": true
}
```

---

## 🎨 Theming System (Centralized Styling)

Create a single file at:

```
frontend/Theme/ThemeManager.swift
```

### `ThemeManager.swift` Contents

```swift
import SwiftUI

struct AppTheme {
    let primaryColor: Color
    let backgroundColor: Color
    let textColor: Color
    let secondaryColor: Color
    let successColor: Color
    let errorColor: Color
    let cornerRadius: CGFloat
    let font: Font
}

final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme

    init() {
        self.theme = AppTheme(
            primaryColor: Color("Primary"),
            backgroundColor: Color("Background"),
            textColor: Color("Text"),
            secondaryColor: Color.gray.opacity(0.2),
            successColor: Color.green,
            errorColor: Color.red,
            cornerRadius: 12,
            font: .system(size: 14, weight: .regular)
        )
    }
}
```

### Inject into SwiftUI root view

```swift
@main
struct LoraChatApp: App {
    @StateObject var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
        }
    }
}
```

### Usage in Views

```swift
@EnvironmentObject var themeManager: ThemeManager

Text("Encrypted Message")
    .padding()
    .background(themeManager.theme.primaryColor)
    .foregroundColor(themeManager.theme.textColor)
    .cornerRadius(themeManager.theme.cornerRadius)
    .font(themeManager.theme.font)
```

> 💡 All UI elements should consume style values via `themeManager.theme`, **never hardcoded values**.

---

## 🗂 Suggested Project Structure

```
/lora-chat-app/
├── frontend/
│   ├── App.swift
│   ├── Views/
│   ├── Theme/
│   │   └── ThemeManager.swift
│   ├── Assets/
│   └── Icons/
├── backend/
│   ├── src/
│   │   ├── main.rs
│   │   ├── serial.rs
│   │   ├── bt.rs
│   │   ├── crypto.rs
│   │   └── messages.rs
├── shared/
│   └── MessageSchema.rs
├── docs/
│   └── encryption.md
│   └── bluetooth.md
│   └── style-tokens.md
└── README.md
```

---

## 📦 MVP Feature Checklist

- [x] SwiftUI Carbon-style interface
- [x] AES-128 encryption with Keychain
- [x] Encrypted message UI with lock icon
- [x] Serial + Bluetooth LoRa connections
- [x] Smart message delivery + retries
- [x] Message queue during offline periods
- [x] ThemeManager for centralized style control
- [x] Chat history stored locally
- [x] Adjustable radio settings (SF, BW, TX Power)

---

## 🧪 Test Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| No device connected | Show alert + fallback mode |
| Serial device connected | Auto-detect and connect |
| Bluetooth LoRa found | Prompt to pair |
| Message fails to decrypt | Show red warning with 🔓 icon |
| Encryption toggle off | Message sent in plaintext |
| Modify `ThemeManager.swift` | Entire UI updates without changing other files |

---

## 📐 Design Principle

> “A precision messaging tool with the ease of iMessages and the reliability of LoRa.”

Styled with Carbon, built with Swift & Rust, trusted in the field.