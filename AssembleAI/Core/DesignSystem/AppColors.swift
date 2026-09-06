//
//  AppColors.swift
//  AssembleAI
//

import SwiftUI

/// Centralized design system colors following Apple Human Interface Guidelines and precision industrial hardware aesthetics.
/// Uses semantic system colors, deep obsidian dark mode, crisp titanium contrasts, and high-visibility International Orange accents.
enum AppColors {
    // Brand Palette: High-precision studio orange / action copper (Apple Watch Ultra & Industrial Hardware aesthetic)
    static let brandPrimary = Color("BrandPrimary", bundle: nil)
    
    /// Dynamic brand accent for primary controls and brand mark
    static var brandAccent: Color {
        brandPrimary
    }
    
    // Semantic System Surfaces
    static let appBackground = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Precision Industrial Titanium Surfaces
    static let titaniumSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let obsidianCard = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Typography Colors
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let placeholderText = Color(uiColor: .placeholderText)
    
    // Semantic Status Colors (Native Apple HIG System Colors)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)

    // Semantic Status Colors (Tutor & Live Feedback States)
    static let statusLive = Color(uiColor: .systemGreen)
    static let statusListening = Color(uiColor: .systemBlue)
    static let statusSpeaking = Color(uiColor: .systemPurple)
    static let statusVerifying = brandPrimary
    static let statusPaused = Color(uiColor: .systemGray)
    static let statusSuccess = success
    static let statusWarning = warning
    static let statusError = error

    // Camera HUD & Overlay Glass Colors (Guaranteed contrast against live camera video)
    static let cameraControlBackground = Color.black.opacity(0.5)
    static let cameraControlForeground = Color.white
    static let cameraCardBorder = Color.white.opacity(0.16)
    static let cameraOverlayScrim = Color.black.opacity(0.3)
    
    // Surface & Border Colors (Crisp, razor-thin Apple boundaries)
    static let separator = Color(uiColor: .separator)
    static let opaqueSeparator = Color(uiColor: .opaqueSeparator)
    static let border = Color(uiColor: .separator).opacity(0.3)
    static let borderSubtle = Color(uiColor: .separator).opacity(0.2)
    static let borderStrong = Color(uiColor: .separator).opacity(0.5)
    static let precisionBorder = Color(uiColor: .separator).opacity(0.5)
    
    // Viewfinder & Optical Measurement Reticles
    static let motifAccent = Color("BrandPrimary", bundle: nil)
    static let motifSecondary = Color(uiColor: .tertiaryLabel)
    static let opticalGrid = Color(uiColor: .tertiaryLabel).opacity(0.3)
    
    // Apple Intelligence Fluid Spectrum Palette
    static let aiCyan = Color(red: 0.18, green: 0.80, blue: 0.98)
    static let aiBlue = Color(red: 0.20, green: 0.45, blue: 0.98)
    static let aiPurple = Color(red: 0.65, green: 0.32, blue: 0.98)
    static let aiPink = Color(red: 0.98, green: 0.28, blue: 0.65)
    static let aiAmber = Color(red: 1.00, green: 0.62, blue: 0.22)
    
    // Glassmorphism & Apple Materials
    static let glassSurface = Color.white.opacity(0.12)
    static let glassBorder = Color.white.opacity(0.22)
    static let glassBorderSubtle = Color.white.opacity(0.12)
    static let glassShadow = Color.black.opacity(0.28)
    
    // MARK: - Premium Atmosphere Design System
    
    // Gradient Atmosphere Backgrounds (Warm cream → peach light / Obsidian → midnight dark)
    static let atmosphereGradientTop = Color(light: Color(red: 1.0, green: 0.973, blue: 0.941),
                                              dark: Color(red: 0.039, green: 0.039, blue: 0.059))
    static let atmosphereGradientMid = Color(light: Color(red: 1.0, green: 0.953, blue: 0.922),
                                              dark: Color(red: 0.047, green: 0.055, blue: 0.078))
    static let atmosphereGradientBottom = Color(light: Color(red: 1.0, green: 0.941, blue: 0.910),
                                                 dark: Color(red: 0.055, green: 0.078, blue: 0.125))
    
    // Ambient Glow Orb Colors
    static let glowPrimary = Color(light: Color(red: 1.0, green: 0.62, blue: 0.22).opacity(0.25),
                                    dark: Color(red: 1.0, green: 0.62, blue: 0.22).opacity(0.12))
    static let glowSecondary = Color(light: Color(red: 0.18, green: 0.80, blue: 0.98).opacity(0.20),
                                      dark: Color(red: 0.18, green: 0.80, blue: 0.98).opacity(0.10))
    
    // Premium Dark CTA Button (Near-black in light / Near-white in dark)
    static let premiumButtonBackground = Color(light: Color(white: 0.11),
                                                dark: Color(white: 0.93))
    static let premiumButtonForeground = Color(light: .white,
                                                dark: Color(white: 0.08))
    
    // Gradient Icon Badge
    static let iconBadgeGradientStart = Color(light: Color(red: 1.0, green: 0.42, blue: 0.12),
                                               dark: Color(red: 1.0, green: 0.52, blue: 0.22))
    static let iconBadgeGradientEnd = Color(light: Color(red: 1.0, green: 0.62, blue: 0.30),
                                              dark: Color(red: 1.0, green: 0.70, blue: 0.38))
    
    // Glassmorphic Card Border (Unified thin white stroke for all glass surfaces)
    static let glassBorderUnified = Color(light: Color.black.opacity(0.06),
                                           dark: Color.white.opacity(0.12))
}

extension Color {
    /// Helper for brand primary color (Precision Studio Orange)
    static var assembleBrandPrimary: Color {
        AppColors.brandPrimary
    }
    
    /// Precision action accent alias
    static var assembleActionAccent: Color {
        AppColors.brandPrimary
    }
    
    /// Apple Intelligence signature gradient colors
    static var appleIntelligenceGradient: [Color] {
        [AppColors.aiCyan, AppColors.aiBlue, AppColors.aiPurple, AppColors.aiPink, AppColors.aiAmber, AppColors.aiCyan]
    }
    
    /// Creates an adaptive color that resolves to `light` in light mode and `dark` in dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
