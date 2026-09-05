//
//  AppTypography.swift
//  AssembleAI
//

import SwiftUI

/// Semantic Typography helpers following Apple Dynamic Type guidelines.
enum AppTypography {
    /// Large app titles (Welcome screen hero title, etc.)
    static func largeTitle(_ text: String) -> Text {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    /// Screen section titles
    static func title(_ text: String) -> Text {
        Text(text)
            .font(.title)
            .fontWeight(.semibold)
    }
    
    /// Card / Sub-section titles
    static func title2(_ text: String) -> Text {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
    }
    
    /// Section headers or key callouts
    static func headline(_ text: String) -> Text {
        Text(text)
            .font(.headline)
    }
    
    /// Standard body text
    static func body(_ text: String) -> Text {
        Text(text)
            .font(.body)
    }
    
    /// Secondary descriptive copy
    static func subheadline(_ text: String) -> Text {
        Text(text)
            .font(.subheadline)
    }
    
    /// Captions, helper text, and legal disclaimers
    static func caption(_ text: String) -> Text {
        Text(text)
            .font(.caption)
    }

    /// Monospaced technical tags and status codes
    static func monospacedTag(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
    }
}

extension View {
    /// Standard section header text style adhering to Apple HIG native title-case guidelines.
    func sectionHeaderStyle() -> some View {
        self
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.secondaryText)
    }

    /// Guarantees that body/caption text wraps across all lines without truncation under Dynamic Type.
    func adaptiveMultiline(alignment: TextAlignment = .leading) -> some View {
        self
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(alignment)
    }

    /// Single line text that smoothly adapts and scales down instead of truncating abruptly.
    func singleLineAdaptive(minScale: CGFloat = 0.8) -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(minScale)
    }

    /// Guarantees Apple HIG minimum interactive touch area (44pt x 44pt).
    func touchTarget(minSize: CGFloat = 44) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

