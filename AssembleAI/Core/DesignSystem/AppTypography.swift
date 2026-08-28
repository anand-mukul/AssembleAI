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
}
