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
            .opacity(configuration.isPressed ? 0.88 : 1.0)
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
                    .fill(Color.assembleBrandPrimary.opacity(0.12))
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

// MARK: - Native Activity Share Sheet (Apple HIG)

/// Reusable wrapper presenting native UIActivityViewController share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Native Primary Action Button (Apple HIG Standard)

/// High-contrast, tactile primary button styled to Apple HIG standards with Dynamic Type support.
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
                        .tint(AppColors.premiumButtonForeground)
                } else {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundColor(AppColors.premiumButtonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(isDisabled ? AppColors.tertiaryText.opacity(0.3) : AppColors.premiumButtonBackground)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1.0)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(AppColors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel(title)
    }
}

// MARK: - Unified Card Modifier & Container (Apple HIG Standard)

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
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
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

// MARK: - Reusable Stat Tile (Apple Health/Fitness Pattern)

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
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.mdSm)
        .padding(.horizontal, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
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
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppColors.tertiaryBackground)
        )
        .overlay(
            Capsule()
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Status Badge

/// Minimal semantic label for difficulty level, sync state, and verification outcomes without capsule clutter.
struct BadgeView: View {
    let text: String
    var color: Color = .assembleBrandPrimary
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
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
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(
                        errorMessage != nil ? AppColors.error : (isFocused ? Color.assembleBrandPrimary : AppColors.borderSubtle),
                        lineWidth: isFocused || errorMessage != nil ? 1.5 : 0.5
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }
}

// MARK: - Gradient Atmosphere Background

/// Reusable atmospheric gradient background. On content screens, cleanly resolves to native system grouped background.
enum AtmosphereIntensity {
    case hero
    case subtle
}

struct GradientAtmosphereBackground: View {
    var intensity: AtmosphereIntensity = .hero
    
    var body: some View {
        if intensity == .hero {
            LinearGradient(
                colors: [
                    AppColors.atmosphereGradientTop,
                    AppColors.atmosphereGradientMid,
                    AppColors.atmosphereGradientBottom,
                    AppColors.appBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            AppColors.groupedBackground
                .ignoresSafeArea()
        }
    }
}

// MARK: - Apple Settings-Style Semantic Icon Badge

/// Authentic Apple Settings squircle icon badge (30x30pt, 7pt continuous corner radius).
/// Replaces generic oversaturated gradient squares with purposeful semantic color coding.
struct SemanticIconBadge: View {
    let iconName: String
    var size: CGFloat = 30
    var iconSize: CGFloat = 15
    var color: Color = AppColors.badgeBlue
    
    init(iconName: String, size: CGFloat = 30, iconSize: CGFloat = 15, color: Color = AppColors.badgeBlue) {
        self.iconName = iconName
        self.size = size
        self.iconSize = iconSize
        self.color = color
    }
    
    init(systemName: String, size: CGFloat = 30, iconSize: CGFloat = 15, tintColor: Color = AppColors.badgeBlue) {
        self.iconName = systemName
        self.size = size
        self.iconSize = iconSize
        self.color = tintColor
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.iconBadge, style: .continuous)
                .fill(color)
                .frame(width: size, height: size)
            
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Unified Icon Badge (Backward Compatible)

/// Standard Apple-style rounded squircle icon badge.
struct GradientIconBadge: View {
    let iconName: String
    var size: CGFloat = 30
    var iconSize: CGFloat = 15
    var colors: [Color]? = nil
    var color: Color? = nil
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.iconBadge, style: .continuous)
                .fill(
                    color != nil
                    ? AnyShapeStyle(color!)
                    : (colors != nil && colors!.count > 1
                       ? AnyShapeStyle(LinearGradient(colors: colors!, startPoint: .topLeading, endPoint: .bottomTrailing))
                       : AnyShapeStyle(colors?.first ?? AppColors.brandPrimary))
                )
                .frame(width: size, height: size)
            
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Animated Header Icon

/// Reusable centered icon-in-circle with entrance scale + opacity animation for hero sections.
struct AnimatedHeaderIcon: View {
    let iconName: String
    var iconSize: CGFloat = 30
    var circleDiameter: CGFloat = 64
    var useGradient: Bool = false
    var staticColor: Color = .assembleBrandPrimary
    
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            Circle()
                .fill(staticColor.opacity(0.12))
                .frame(width: circleDiameter, height: circleDiameter)
            
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(staticColor)
        }
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.heroReveal) {
                appeared = true
            }
        }
    }
}

// MARK: - Section Header Extension Helper

extension View {
    /// Apple HIG standard section header typography and alignment.
    func standardSectionHeader() -> some View {
        self
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.secondaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
