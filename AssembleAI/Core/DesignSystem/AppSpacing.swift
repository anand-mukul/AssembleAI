//
//  AppSpacing.swift
//  AssembleAI
//

import SwiftUI

/// Standard spacing grid constants adhering to Apple HIG 4pt base grid layout rhythms.
enum AppSpacing {
    /// 2pt micro spacing
    static let xxs: CGFloat = 2
    /// 4pt tight spacing
    static let xs: CGFloat = 4
    /// 8pt compact spacing
    static let sm: CGFloat = 8
    /// 12pt medium-small spacing
    static let mdSm: CGFloat = 12
    /// 16pt standard content & screen edge spacing (Apple HIG standard)
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
    
    /// Standard horizontal inset for screen-edge content (matches Apple native 20pt layout margin)
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
    /// 14pt standard Apple control radius for buttons and text fields
    static let md: CGFloat = 14
    /// 18pt standard Apple HIG grouped card radius (concentric to inner 8-10pt badges)
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
    /// Standard cascading delay per item in staggered lists (0.04s)
    static let staggerDelay: Double = 0.04
    /// Native iOS 17 smooth spring for standard view transitions
    static let standard: Animation = .smooth(duration: 0.3)
    /// Native iOS 17 snappy spring for user-initiated micro-interactions
    static let quick: Animation = .snappy(duration: 0.25)
    /// Native iOS 17 bouncy spring for confirmations and success cues
    static let feedback: Animation = .bouncy(duration: 0.35)
    /// Entrance spring for staggered card appearances
    static let entranceSpring: Animation = .smooth(duration: 0.35)
    /// Slower reveal for hero centerpieces
    static let heroReveal: Animation = .smooth(duration: 0.5)
    /// Quick spring for button taps and state changes
    static let microInteraction: Animation = .snappy(duration: 0.2)
}
