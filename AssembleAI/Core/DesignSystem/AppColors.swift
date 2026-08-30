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
}

