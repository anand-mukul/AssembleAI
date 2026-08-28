//
//  AppColors.swift
//  AssembleAI
//

import SwiftUI

/// Centralized design system colors following Apple Human Interface Guidelines.
/// Uses semantic system colors for Dark/Light mode, Dynamic Type, and high-contrast support.
enum AppColors {
    // Brand Palette (Restrained, precise, technical accent)
    static let brandPrimary = Color("BrandPrimary", bundle: nil)
        .opacity(1.0)
    
    /// Dynamic brand accent for primary controls and brand mark
    static var brandAccent: Color {
        Color.accentColor
    }
    
    // Semantic System Colors
    static let appBackground = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Typography Colors
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let placeholderText = Color(uiColor: .placeholderText)
    
    // Status & Feedback Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // Surface & Border Colors
    static let separator = Color(uiColor: .separator)
    static let opaqueSeparator = Color(uiColor: .opaqueSeparator)
    static let border = Color(uiColor: .separator)
    
    // Subdued camera/viewfinder motif tint
    static let motifAccent = Color.blue
    static let motifSecondary = Color(uiColor: .tertiaryLabel)
}

extension Color {
    /// Helper for brand primary fallback if custom asset isn't compiled
    static var assembleBrandPrimary: Color {
        Color.indigo
    }
}
