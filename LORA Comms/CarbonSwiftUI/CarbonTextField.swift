import SwiftUI

// MARK: - Carbon TextField Component

public struct CarbonTextField: View {
    // MARK: - Properties
    
    @Binding private var text: String
    private let placeholder: String
    private let label: String?
    private let helperText: String?
    private let errorText: String?
    private let isSecure: Bool
    private let isDisabled: Bool
    
    @FocusState private var isFocused: Bool
    
    // MARK: - Initializer
    
    public init(
        text: Binding<String>,
        placeholder: String,
        label: String? = nil,
        helperText: String? = nil,
        errorText: String? = nil,
        isSecure: Bool = false,
        isDisabled: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.label = label
        self.helperText = helperText
        self.errorText = errorText
        self.isSecure = isSecure
        self.isDisabled = isDisabled
    }
    
    // MARK: - Computed Properties
    
    private var hasError: Bool {
        return errorText != nil
    }
    
    private var borderColor: Color {
        if hasError {
            return CarbonTheme.ColorPalette.red
        } else if isFocused {
            return CarbonTheme.ColorPalette.interactive
        } else {
            return CarbonTheme.ColorPalette.textSecondary
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            if let label = label {
                Text(label)
                    .font(CarbonTheme.Typography.plexSans(size: 12, weight: .medium))
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
            }
            
            // Text Field
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(CarbonTheme.Typography.plexSans(size: 14))
            .foregroundColor(isDisabled ? CarbonTheme.ColorPalette.textSecondary : CarbonTheme.ColorPalette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(isDisabled ? CarbonTheme.ColorPalette.surface.opacity(0.5) : CarbonTheme.ColorPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .focused($isFocused)
            .disabled(isDisabled)
            .accessibilityLabel(label ?? placeholder)
            .accessibilityHint(helperText ?? "")
            .accessibilityValue(hasError ? "Error: \(errorText ?? "")" : "")
            
            // Helper or Error Text
            if let errorText = errorText {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(CarbonTheme.ColorPalette.red)
                        .font(.caption)
                    
                    Text(errorText)
                        .font(CarbonTheme.Typography.plexSans(size: 12))
                        .foregroundColor(CarbonTheme.ColorPalette.red)
                }
            } else if let helperText = helperText {
                Text(helperText)
                    .font(CarbonTheme.Typography.plexSans(size: 12))
                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 24) {
        CarbonTextField(
            text: .constant(""),
            placeholder: "Enter your message",
            label: "Message"
        )
        
        CarbonTextField(
            text: .constant("Sample text"),
            placeholder: "Enter your message",
            label: "Message with helper text",
            helperText: "This is a helper text to aid the user."
        )
        
        CarbonTextField(
            text: .constant("Error text"),
            placeholder: "Enter your message",
            label: "Message with error",
            errorText: "This field is required."
        )
        
        CarbonTextField(
            text: .constant(""),
            placeholder: "Enter password",
            label: "Password",
            isSecure: true
        )
        
        CarbonTextField(
            text: .constant("Disabled"),
            placeholder: "Enter your message",
            label: "Disabled field",
            isDisabled: true
        )
    }
    .padding()
    .background(CarbonTheme.ColorPalette.background)
}
