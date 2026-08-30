//
//  DifficultyBadge.swift
//  AssembleAI
//

import SwiftUI

/// Semantic indicator for project difficulty level adhering to Apple HIG typography.
struct DifficultyBadge: View {
    let difficulty: Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(difficulty.color)
            .accessibilityLabel("Difficulty: \(difficulty.rawValue)")
    }
}

#Preview("Difficulty Badge") {
    HStack(spacing: 12) {
        DifficultyBadge(difficulty: .beginner)
        DifficultyBadge(difficulty: .intermediate)
        DifficultyBadge(difficulty: .advanced)
    }
}
