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
    
    /// Standard horizontal inset for screen-edge content (matches Apple native 20pt inset)
    static let screenEdge: CGFloat = 20
}

/// Unified corner radius tokens adhering to Apple iOS continuous curvature standards.
enum AppRadius {
    /// 8pt tight chips / small indicators
    static let xs: CGFloat = 8
    /// 10pt for buttons, badges, and smaller inputs
    static let sm: CGFloat = 10
    /// 14pt for interactive control fields and secondary buttons
    static let md: CGFloat = 14
    /// 18pt standard for cards, tiles, and containers
    static let card: CGFloat = 18
    /// 22pt for hero visual centerpieces and prominent modules
    static let lg: CGFloat = 22
    /// 28pt for bottom sheets and large presentation detents
    static let sheet: CGFloat = 28
}

/// Standardized elevation shadows.
enum AppShadow {
    static let subtleColor = Color.black.opacity(0.04)
    static let mediumColor = Color.black.opacity(0.08)
    static let elevatedColor = Color.black.opacity(0.18)
}

