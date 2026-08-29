//
//  ProjectVisualCard.swift
//  AssembleAI
//

import SwiftUI

/// Clean, Apple-native technical illustration card for assembly projects using vector shapes and SF Symbols.
struct ProjectVisualCard: View {
    let category: String
    let iconName: String?
    var height: CGFloat = 140
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                )
            
            // Subdued Circuit Blueprint Grid Lines Pattern
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                Path { path in
                    // Horizontal grid line
                    path.move(to: CGPoint(x: 16, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w - 16, y: h * 0.5))
                    
                    // Vertical grid line
                    path.move(to: CGPoint(x: w * 0.3, y: 16))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h - 16))
                    
                    path.move(to: CGPoint(x: w * 0.7, y: 16))
                    path.addLine(to: CGPoint(x: w * 0.7, y: h - 16))
                }
                .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            
            // Central Component Visual
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: iconName ?? "cpu")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.tertiaryText)
                    .tracking(1.2)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview("Project Visual Card") {
    ProjectVisualCard(category: "Electronics", iconName: "bolt.batteryblock.fill")
        .padding()
}
