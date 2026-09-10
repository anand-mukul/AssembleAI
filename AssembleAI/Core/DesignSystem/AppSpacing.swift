//
//  AppSpacing.swift
//  AssembleAI
//

import SwiftUI

/// Standard spacing grid constants adhering to Apple HIG 8pt grid layout rhythms.
enum AppSpacing {
    /// 2pt micro spacing
    static let xxs: CGFloat = 2
    /// 4pt tight spacing
    static let xs: CGFloat = 4
    /// 8pt compact spacing
    static let sm: CGFloat = 8
    /// 12pt medium-small spacing
    static let mdSm: CGFloat = 12
    /// 16pt standard content spacing
    static let md: CGFloat = 16
    /// 20pt comfortable content spacing
    static let mdLg: CGFloat = 20
    /// 24pt spacious section padding
    static let lg: CGFloat = 24
    /// 32pt extra large hero spacing
    static let xl: CGFloat = 32
    /// 48pt section divider spacing
    static let xxl: CGFloat = 48
    /// 64pt top hero margin spacing
    static let xxxl: CGFloat = 64
    
    /// Standard horizontal inset for screen-edge content (matches Apple native 20pt standard margin)
    static let screenEdge: CGFloat = 20
    
    /// Standard internal padding for cards (16pt)
    static let cardPadding: CGFloat = 16
    
    /// Standard divider leading inset for grouped list cards with icon badges (16pt padding + 30pt badge + 10pt gap = 56pt)
    static let dividerLeadingInset: CGFloat = 56
    
    /// Standard Apple HIG button height (50pt)
    static let buttonHeight: CGFloat = 50
}

/// Unified corner radius tokens adhering to Apple iOS continuous curvature standards.
enum AppRadius {
    /// 7pt standard for 30x30 Apple Settings squircle icon badges
    static let iconBadge: CGFloat = 7
    /// 8pt tight chips / small indicators
    static let xs: CGFloat = 8
    /// 10pt for badges and small inputs
    static let sm: CGFloat = 10
    /// 14pt for interactive control fields and secondary buttons
    static let md: CGFloat = 14
    /// 18pt standard Apple HIG grouped card radius
    static let card: CGFloat = 18
    /// 22pt for hero visual centerpieces and prominent modules
    static let lg: CGFloat = 22
    /// 28pt for bottom sheets and large presentation detents
    static let sheet: CGFloat = 28
}

/// Standardized elevation shadows adhering to Apple HIG subtlety.
enum AppShadow {
    static let subtleColor = Color.black.opacity(0.03)
    static let mediumColor = Color.black.opacity(0.06)
    static let elevatedColor = Color.black.opacity(0.12)
}

/// Unified animation timing tokens for consistent motion across all screens.
enum AppAnimation {
    /// Standard cascading delay per item in staggered lists (0.05s)
    static let staggerDelay: Double = 0.05
    /// Shared spring response for screen entrance animations
    static let entranceSpring: Animation = .spring(response: 0.45, dampingFraction: 0.84)
    /// Slower spring for hero section reveals
    static let heroReveal: Animation = .spring(response: 0.6, dampingFraction: 0.8)
    /// Quick spring for micro-interactions and state changes
    static let microInteraction: Animation = .spring(response: 0.25, dampingFraction: 0.78)
}
