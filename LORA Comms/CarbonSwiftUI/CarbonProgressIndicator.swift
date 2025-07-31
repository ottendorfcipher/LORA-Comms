import SwiftUI

// MARK: - Carbon Progress Indicator Component

public struct CarbonProgressIndicator: View {
    // MARK: - Properties
    
    private let value: Double
    private let total: Double
    private let type: ProgressType
    private let size: ProgressSize
    private let label: String?
    private let showPercentage: Bool
    private let isIndeterminate: Bool
    
    @State private var animationOffset: Double = 0
    
    // MARK: - Progress Types
    
    public enum ProgressType {
        case linear
        case circular
        
        var height: CGFloat {
            switch self {
            case .linear:
                return 4
            case .circular:
                return 0 // Handled by size
            }
        }
    }
    
    // MARK: - Progress Sizes
    
    public enum ProgressSize {
        case small
        case medium
        case large
        
        var circularDiameter: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 48
            }
        }
        
        var strokeWidth: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
    }
    
    // MARK: - Initializers
    
    public init(
        value: Double,
        total: Double = 100,
        type: ProgressType = .linear,
        size: ProgressSize = .medium,
        label: String? = nil,
        showPercentage: Bool = false
    ) {
        self.value = value
        self.total = total
        self.type = type
        self.size = size
        self.label = label
        self.showPercentage = showPercentage
        self.isIndeterminate = false
    }
    
    public init(
        indeterminate: Bool = true,
        type: ProgressType = .linear,
        size: ProgressSize = .medium,
        label: String? = nil
    ) {
        self.value = 0
        self.total = 100
        self.type = type
        self.size = size
        self.label = label
        self.showPercentage = false
        self.isIndeterminate = indeterminate
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and percentage
            if label != nil || showPercentage {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(CarbonTheme.Typography.plexSans(size: 12, weight: .medium))
                            .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    }
                    
                    Spacer()
                    
                    if showPercentage && !isIndeterminate {
                        Text("\(percentage)%")
                            .font(CarbonTheme.Typography.plexSans(size: 12, weight: .medium))
                            .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                    }
                }
            }
            
            // Progress indicator
            switch type {
            case .linear:
                linearProgressView
            case .circular:
                circularProgressView
            }
        }
    }
    
    // MARK: - Linear Progress View
    
    private var linearProgressView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: type.height / 2)
                    .fill(CarbonTheme.ColorPalette.surface)
                    .frame(height: type.height)
                
                // Progress fill
                if isIndeterminate {
                    // Indeterminate animation
                    RoundedRectangle(cornerRadius: type.height / 2)
                        .fill(CarbonTheme.ColorPalette.interactive)
                        .frame(width: geometry.size.width * 0.3, height: type.height)
                        .offset(x: animationOffset)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: animationOffset
                        )
                        .onAppear {
                            animationOffset = geometry.size.width * 1.3
                        }
                } else {
                    // Determinate progress
                    RoundedRectangle(cornerRadius: type.height / 2)
                        .fill(CarbonTheme.ColorPalette.interactive)
                        .frame(width: geometry.size.width * progress, height: type.height)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
        }
        .frame(height: type.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue(isIndeterminate ? "Loading" : "\(percentage) percent")
    }
    
    // MARK: - Circular Progress View
    
    private var circularProgressView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    CarbonTheme.ColorPalette.surface,
                    style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round)
                )
            
            if isIndeterminate {
                // Indeterminate circular animation
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        CarbonTheme.ColorPalette.interactive,
                        style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(animationOffset))
                    .animation(
                        Animation.linear(duration: 1.0)
                            .repeatForever(autoreverses: false),
                        value: animationOffset
                    )
                    .onAppear {
                        animationOffset = 360
                    }
            } else {
                // Determinate circular progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        CarbonTheme.ColorPalette.interactive,
                        style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(width: size.circularDiameter, height: size.circularDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue(isIndeterminate ? "Loading" : "\(percentage) percent")
    }
}

// MARK: - Progress Step Component

public struct CarbonProgressSteps: View {
    // MARK: - Properties
    
    private let steps: [StepModel]
    private let currentStep: Int
    private let orientation: Orientation
    
    // MARK: - Step Model
    
    public struct StepModel {
        public let id: String
        public let title: String
        public let description: String?
        public let isOptional: Bool
        
        public init(id: String, title: String, description: String? = nil, isOptional: Bool = false) {
            self.id = id
            self.title = title
            self.description = description
            self.isOptional = isOptional
        }
    }
    
    // MARK: - Orientation
    
    public enum Orientation {
        case horizontal
        case vertical
    }
    
    // MARK: - Initializer
    
    public init(
        steps: [StepModel],
        currentStep: Int,
        orientation: Orientation = .horizontal
    ) {
        self.steps = steps
        self.currentStep = currentStep
        self.orientation = orientation
    }
    
    // MARK: - Body
    
    public var body: some View {
        switch orientation {
        case .horizontal:
            horizontalStepsView
        case .vertical:
            verticalStepsView
        }
    }
    
    // MARK: - Horizontal Steps View
    
    private var horizontalStepsView: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 0) {
                    // Step indicator
                    stepIndicator(for: index, step: step)
                    
                    // Connector line (except for last step)
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(stepState(for: index).connectorColor)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    // MARK: - Vertical Steps View
    
    private var verticalStepsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        // Step indicator
                        stepIndicator(for: index, step: step)
                        
                        // Step content
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(CarbonTheme.Typography.plexSans(size: 14, weight: .medium))
                                .foregroundColor(stepState(for: index).textColor)
                            
                            if let description = step.description {
                                Text(description)
                                    .font(CarbonTheme.Typography.plexSans(size: 12))
                                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                            }
                            
                            if step.isOptional {
                                Text("Optional")
                                    .font(CarbonTheme.Typography.plexSans(size: 10, weight: .medium))
                                    .foregroundColor(CarbonTheme.ColorPalette.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(CarbonTheme.ColorPalette.textSecondary, lineWidth: 1)
                                    )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    
                    // Connector line (except for last step)
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(stepState(for: index).connectorColor)
                            .frame(width: 2)
                            .frame(height: 20)
                            .offset(x: 12) // Align with indicator center
                    }
                }
            }
        }
    }
    
    // MARK: - Step Indicator
    
    private func stepIndicator(for index: Int, step: StepModel) -> some View {
        let state = stepState(for: index)
        
        return ZStack {
            Circle()
                .fill(state.backgroundColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(state.borderColor, lineWidth: 2)
                )
            
            if state.isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(CarbonTheme.ColorPalette.textPrimary)
                    .font(.system(size: 10, weight: .bold))
            } else {
                Text("\(index + 1)")
                    .font(CarbonTheme.Typography.plexSans(size: 12, weight: .semibold))
                    .foregroundColor(state.textColor)
            }
        }
        .accessibilityLabel("Step \(index + 1): \(step.title)")
        .accessibilityValue(state.accessibilityState)
    }
    
    // MARK: - Step State
    
    private struct StepState {
        let backgroundColor: Color
        let borderColor: Color
        let textColor: Color
        let connectorColor: Color
        let isCompleted: Bool
        let accessibilityState: String
    }
    
    private func stepState(for index: Int) -> StepState {
        if index < currentStep {
            // Completed
            return StepState(
                backgroundColor: CarbonTheme.ColorPalette.green,
                borderColor: CarbonTheme.ColorPalette.green,
                textColor: CarbonTheme.ColorPalette.textPrimary,
                connectorColor: CarbonTheme.ColorPalette.green,
                isCompleted: true,
                accessibilityState: "Completed"
            )
        } else if index == currentStep {
            // Current
            return StepState(
                backgroundColor: CarbonTheme.ColorPalette.interactive,
                borderColor: CarbonTheme.ColorPalette.interactive,
                textColor: CarbonTheme.ColorPalette.textPrimary,
                connectorColor: CarbonTheme.ColorPalette.surface,
                isCompleted: false,
                accessibilityState: "Current"
            )
        } else {
            // Upcoming
            return StepState(
                backgroundColor: CarbonTheme.ColorPalette.surface,
                borderColor: CarbonTheme.ColorPalette.surface,
                textColor: CarbonTheme.ColorPalette.textSecondary,
                connectorColor: CarbonTheme.ColorPalette.surface,
                isCompleted: false,
                accessibilityState: "Upcoming"
            )
        }
    }
}

// MARK: - Previews

#Preview("Progress Indicators") {
    VStack(spacing: 32) {
        // Linear progress
        VStack(spacing: 16) {
            CarbonProgressIndicator(
                value: 65,
                label: "Downloading firmware",
                showPercentage: true
            )
            
            CarbonProgressIndicator(
                indeterminate: true,
                label: "Connecting to device"
            )
        }
        
        // Circular progress
        HStack(spacing: 32) {
            CarbonProgressIndicator(
                value: 75,
                type: .circular,
                size: .large,
                showPercentage: true
            )
            
            CarbonProgressIndicator(
                indeterminate: true,
                type: .circular,
                size: .medium
            )
        }
        
        // Progress steps
        CarbonProgressSteps(
            steps: [
                CarbonProgressSteps.StepModel(id: "1", title: "Device Detection", description: "Scanning for available devices"),
                CarbonProgressSteps.StepModel(id: "2", title: "Connection", description: "Establishing secure connection"),
                CarbonProgressSteps.StepModel(id: "3", title: "Configuration", description: "Setting up device parameters", isOptional: true),
                CarbonProgressSteps.StepModel(id: "4", title: "Verification", description: "Testing connection")
            ],
            currentStep: 1,
            orientation: .vertical
        )
    }
    .padding()
    .background(CarbonTheme.ColorPalette.background)
}
