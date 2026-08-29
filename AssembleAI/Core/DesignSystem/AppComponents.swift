//
//  AppComponents.swift
//  AssembleAI
//

import SwiftUI

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
        VStack(spacing: size == .large ? AppSpacing.sm : AppSpacing.xs) {
            // App Brand Mark (Precision Camera + Assembly symbol)
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
            
            // App Name
            Text("AssembleAI")
                .font(size == .large ? .largeTitle : (size == .medium ? .title : .title2))
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            // Tagline
            Text("Build with confidence.")
                .font(size == .large ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AssembleAI. Build with confidence.")
    }
    
    private var markDiameter: CGFloat {
        switch size {
        case .compact: return 48
        case .medium: return 64
        case .large: return 80
        }
    }
    
    private var iconFontSize: CGFloat {
        switch size {
        case .compact: return 24
        case .medium: return 32
        case .large: return 42
        }
    }
    
    private var subIconFontSize: CGFloat {
        switch size {
        case .compact: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
}

// MARK: - Assembly Camera Visual Motif

/// Custom Apple-quality SwiftUI visual composition illustrating an iPhone camera observing a physical assembly object.
/// Built without generic AI artwork, using SF Symbols, reticles, alignment marks, and circuit board motifs.
struct AssemblyCameraMotifView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulseAnimating = false
    
    var body: some View {
        ZStack {
            // Background subtle grid canvas
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.5), lineWidth: 1)
                )
            
            VStack(spacing: AppSpacing.md) {
                // Viewfinder Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("OBSERVING TASK")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiaryText)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                
                // Central Assembly Inspection Canvas
                ZStack {
                    // Physical Assembly Component (PCB / Chip representation)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(width: 140, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                        )
                    
                    // Circuit traces & component pin lines
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.indigo.opacity(0.7))
                                .frame(width: 14, height: 14)
                            Rectangle()
                                .fill(Color.indigo.opacity(0.4))
                                .frame(width: 2, height: 28)
                        }
                        
                        VStack(spacing: 6) {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.primaryText.opacity(0.8))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.success)
                                Text("COMPONENTS OK")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.indigo.opacity(0.4))
                                .frame(width: 2, height: 28)
                            Circle()
                                .fill(Color.indigo.opacity(0.7))
                                .frame(width: 14, height: 14)
                        }
                    }
                    
                    // Camera Bounding Reticle Box
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            Color.assembleBrandPrimary,
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .frame(width: 170, height: 130)
                        .scaleEffect(reduceMotion ? 1.0 : (isPulseAnimating ? 1.03 : 0.98))
                    
                    // Four Corner Camera Framing Crosshairs
                    CameraCornersView()
                        .frame(width: 184, height: 144)
                        .foregroundColor(Color.assembleBrandPrimary)
                }
                .padding(.vertical, AppSpacing.xs)
                
                // Status readout pill
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.assembleBrandPrimary)
                    Text("State-Aware Verification")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(.horizontal, AppSpacing.mdSm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.appBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                )
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .frame(height: 220)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isPulseAnimating = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration of AssembleAI camera scanning physical electronic component for verification.")
    }
}

/// Viewfinder Corner Crosshairs
struct CameraCornersView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 16
            
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
            .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Primary Action Button

/// Full-width primary button styled to native Apple HIG standards with loading indicator support.
struct PrimaryButton: View {
    let title: String
    var iconName: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.headline)
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDisabled ? AppColors.tertiaryText.opacity(0.28) : Color.assembleBrandPrimary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.78 : 1)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "Button is disabled" : "Tap to proceed")
    }
}

// MARK: - Secondary Action Button

/// Secondary bordered button style.
struct SecondaryButton: View {
    let title: String
    var iconName: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(AppColors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.border.opacity(0.75), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(title)
    }
}

// MARK: - Badge

/// Compact status badge for labels like difficulty and sync state.
struct BadgeView: View {
    let text: String
    var color: Color = .assembleBrandPrimary
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .accessibilityLabel(text)
    }
}

// MARK: - Custom Input Text Field

/// Standardized native text field with icon, focus highlighting, and error feedback.
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
            
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundColor(isFocused ? .assembleBrandPrimary : AppColors.secondaryText)
                    .frame(width: 20)
                
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .submitLabel(submitLabel)
                        .onSubmit(onCommit)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                        .disableAutocorrection(isSecure || keyboardType == .emailAddress)
                        .submitLabel(submitLabel)
                        .onSubmit(onCommit)
                        .focused($isFocused)
                }
                
                if isSecure {
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(AppColors.tertiaryText)
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
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        errorMessage != nil ? AppColors.error : (isFocused ? Color.assembleBrandPrimary : AppColors.border.opacity(0.65)),
                        lineWidth: isFocused || errorMessage != nil ? 1.5 : 1
                    )
            )
            
            if let errorMessage = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                .padding(.leading, AppSpacing.xs)
                .transition(.opacity)
            }
        }
    }
}
