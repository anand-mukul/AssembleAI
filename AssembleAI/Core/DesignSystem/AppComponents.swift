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
                Text("Precision Hardware Assembly & Optical Inspection")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AssembleAI. Precision Hardware Assembly.")
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

/// Calm, serene visual centerpiece representing AssembleAI's quiet spatial awareness.
struct AssemblyCameraMotifView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    
    var body: some View {
        ZStack {
            // Ambient soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.assembleBrandPrimary.opacity(0.12),
                            Color.assembleBrandPrimary.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.05 : 0.95))
            
            // Soft frosted disc container
            Circle()
                .fill(AppColors.secondaryGroupedBackground)
                .frame(width: 96, height: 96)
                .overlay(
                    Circle()
                        .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                )
                .shadow(color: AppShadow.subtleColor, radius: 10, x: 0, y: 4)

            // Central calm Thinking Orb
            ThinkingOrbView(status: .live, diameter: 54)

            // Minimal subtle viewfinder reticle marks
            CameraCornersView()
                .frame(width: 120, height: 120)
                .foregroundColor(Color.assembleBrandPrimary.opacity(0.35))
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AssembleAI ambient visual guide.")
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

/// Clean, minimal, full-width primary button styled strictly to Apple HIG standards with Dynamic Type support.
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isDisabled ? AppColors.tertiaryText.opacity(0.3) : Color.assembleBrandPrimary)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.75 : 1.0)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }
}

// MARK: - Native Secondary Action Button

/// Clean secondary bordered button style with Dynamic Type support.
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(AppColors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1.0)
        .accessibilityLabel(title)
    }
}

// MARK: - Unified Card Modifier & Container

/// Standard Apple-quality card modifier unifying corner radius, background, and crisp subtle borders.
struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    var backgroundColor: Color = AppColors.secondaryGroupedBackground
    var borderColor: Color = AppColors.borderSubtle
    var padding: CGFloat = AppSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    /// Applies the unified AssembleAI card styling.
    func appCard(
        cornerRadius: CGFloat = AppRadius.card,
        backgroundColor: Color = AppColors.secondaryGroupedBackground,
        borderColor: Color = AppColors.borderSubtle,
        padding: CGFloat = AppSpacing.md
    ) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius, backgroundColor: backgroundColor, borderColor: borderColor, padding: padding))
    }
}

// MARK: - Reusable Stat Tile

/// Standardized statistic metric tile used across summary, completion, and profile screens.
struct StatTile: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .assembleBrandPrimary

    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Reusable Status Pill

/// Calm, Apple-quality status indicator pill.
struct StatusPill: View {
    let text: String
    var status: LiveTutorStatus? = nil
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let status = status {
                ThinkingOrbView(status: status, diameter: 14)
            } else if let dotColor = dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }

            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.ultraThinMaterial))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(text)")
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
