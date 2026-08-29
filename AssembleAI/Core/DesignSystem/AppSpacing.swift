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
