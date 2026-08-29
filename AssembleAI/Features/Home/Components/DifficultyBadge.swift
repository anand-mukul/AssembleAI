//
//  DifficultyBadge.swift
//  AssembleAI
//

import SwiftUI

/// Semantic badge for project difficulty level.
struct DifficultyBadge: View {
    let difficulty: Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(difficulty.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(difficulty.color.opacity(0.12))
            )
            .accessibilityLabel("Difficulty: \(difficulty.rawValue)")
    }
}

#Preview("Difficulty Badge") {
    HStack(spacing: 8) {
        DifficultyBadge(difficulty: .beginner)
        DifficultyBadge(difficulty: .intermediate)
        DifficultyBadge(difficulty: .advanced)
    }
}
