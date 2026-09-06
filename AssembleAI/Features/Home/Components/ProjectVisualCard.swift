//
//  ProjectVisualCard.swift
//  AssembleAI
//

import SwiftUI

/// Clean, Apple-native technical illustration card for assembly projects using vector shapes and blueprint grid.
struct ProjectVisualCard: View {
    let category: String
    let iconName: String?
    var height: CGFloat = 140
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                )
                .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
            
            // Subdued Circuit Blueprint Grid Lines Pattern
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                Path { path in
                    // Horizontal grid lines
                    path.move(to: CGPoint(x: 20, y: h * 0.33))
                    path.addLine(to: CGPoint(x: w - 20, y: h * 0.33))
                    
                    path.move(to: CGPoint(x: 20, y: h * 0.66))
                    path.addLine(to: CGPoint(x: w - 20, y: h * 0.66))
                    
                    // Vertical grid lines
                    path.move(to: CGPoint(x: w * 0.3, y: 16))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h - 16))
                    
                    path.move(to: CGPoint(x: w * 0.7, y: 16))
                    path.addLine(to: CGPoint(x: w * 0.7, y: h - 16))
                }
                .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            
            // Central Component Visual
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: iconName ?? "cpu")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                Text(category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppColors.tertiaryBackground)
                    )
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
