//
//  AppComponents.swift
//  AssembleAI
//

import SwiftUI
import UIKit

// MARK: - Button Spring Micro-Interaction Style

/// Tactile spring scale button style with optional haptic feedback adhering to Apple HIG guidelines.
struct ScaleButtonStyle: ButtonStyle {
    var enableHaptic: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if enableHaptic && isPressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Brand Header Component

/// Reusable brand header featuring the AssembleAI logo mark, app name, and tagline.
struct BrandHeaderView: View {
    var size: HeaderSize = .large
    
    enum HeaderSize {
        case compact
        case medium
        case large
    }
    
    var body: some View {
        VStack(spacing: size == .large ? AppSpacing.sm : 4) {
            // App Brand Mark (Precision Viewfinder + CPU Core)
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
                    .frame(width: markDiameter, height: markDiameter)
                
                Image(systemName: "viewfinder")
                    .font(.system(size: iconFontSize, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
                
                Image(systemName: "cpu")
                    .font(.system(size: subIconFontSize, weight: .semibold))
                    .foregroundColor(.assembleBrandPrimary)
            }
            .accessibilityHidden(true)
            
            Text("AssembleAI")
                .font(size == .large ? .title : (size == .medium ? .title2 : .headline))
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            if size == .large {
                Text("State-Aware Physical Task Assistant")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AssembleAI. State Aware Physical Task Assistant.")
    }
    
    private var markDiameter: CGFloat {
        switch size {
        case .compact: return 44
        case .medium: return 60
        case .large: return 76
        }
    }
    
    private var iconFontSize: CGFloat {
        switch size {
        case .compact: return 22
        case .medium: return 30
        case .large: return 38
        }
    }
    
    private var subIconFontSize: CGFloat {
        switch size {
        case .compact: return 10
        case .medium: return 14
        case .large: return 18
        }
    }
}

// MARK: - Assembly Camera Visual Centerpiece Motif

/// Apple-quality visual centerpiece displaying live spatial task observation, reticles, alignment crosshairs, and state verification.
struct AssemblyCameraMotifView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulseAnimating = false
    
    var body: some View {
        ZStack {
            // Background Canvas Surface
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                )
            
            VStack(spacing: AppSpacing.md) {
                // Viewfinder Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("CAMERA OBSERVER ACTIVE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.assembleBrandPrimary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                
                // Central Camera Reticle Target
                ZStack {
                    // Physical Task Component Grid Target
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.tertiaryBackground)
                        .frame(width: 156, height: 116)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    
                    // Hardware Component Visual Symbol
                    VStack(spacing: 6) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundColor(AppColors.primaryText)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.success)
                            Text("STEP VERIFIED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    // Reticle Pulsing Boundary Box
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            Color.assembleBrandPrimary,
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .frame(width: 180, height: 136)
                        .scaleEffect(reduceMotion ? 1.0 : (isPulseAnimating ? 1.02 : 0.98))
                    
                    // Corner Alignment Markers
                    CameraCornersView()
                        .frame(width: 194, height: 150)
                        .foregroundColor(Color.assembleBrandPrimary)
                }
                .padding(.vertical, AppSpacing.xs)
                
                // State Verification Badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.assembleBrandPrimary)
                    Text("State-Aware Inspection")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppColors.appBackground)
                )
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .frame(height: 236)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    isPulseAnimating = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AssembleAI spatial camera observing assembly component for verification.")
    }
}

/// Viewfinder Corner Crosshairs
struct CameraCornersView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 14
            
            Path { path in
                // Top Left
                path.move(to: CGPoint(x: 0, y: len))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: len, y: 0))
                
                // Top Right
                path.move(to: CGPoint(x: w - len, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: len))
                
                // Bottom Left
                path.move(to: CGPoint(x: 0, y: h - len))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: len, y: h))
                
                // Bottom Right
                path.move(to: CGPoint(x: w - len, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - len))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Native Primary Action Button

/// Clean, minimal, full-width primary button styled strictly to Apple HIG standards.
struct PrimaryButton: View {
    let title: String
    var iconName: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.body.weight(.medium))
                    }
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDisabled ? AppColors.tertiaryText.opacity(0.3) : Color.assembleBrandPrimary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.75 : 1.0)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }
}

// MARK: - Native Secondary Action Button

/// Clean secondary bordered button style.
struct SecondaryButton: View {
    let title: String
    var iconName: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundColor(AppColors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.border.opacity(0.4), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
        .accessibilityLabel(title)
    }
}

// MARK: - Status Badge

/// Minimal status badge for difficulty level, sync state, and verification outcomes.
struct BadgeView: View {
    let text: String
    var color: Color = .assembleBrandPrimary
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .accessibilityLabel(text)
    }
}

// MARK: - Custom Input Text Field

/// Standardized native text field with icon, focus highlighting, error state, and clear button.
struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var iconName: String
    var isSecure: Bool = false
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var onCommit: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
            
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundColor(isFocused ? .assembleBrandPrimary : AppColors.secondaryText)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .submitLabel(submitLabel)
                        .onSubmit(onCommit)
                        .focused($isFocused)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                        .disableAutocorrection(isSecure || keyboardType == .emailAddress)
                        .submitLabel(submitLabel)
                        .onSubmit(onCommit)
                        .focused($isFocused)
                        .textContentType(keyboardType == .emailAddress ? .emailAddress : nil)
                }
                
                if isSecure {
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(AppColors.tertiaryText)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                } else if !text.isEmpty && isFocused {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .accessibilityLabel("Clear text")
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        errorMessage != nil ? AppColors.error : (isFocused ? Color.assembleBrandPrimary : AppColors.border.opacity(0.4)),
                        lineWidth: isFocused || errorMessage != nil ? 1.5 : 1
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
            
            if let errorMessage = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                .padding(.leading, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }
}
