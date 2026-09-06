//
//  ProjectVisualCard.swift
//  AssembleAI
//

import SwiftUI

/// Clean, Apple-native technical illustration card for assembly projects using vector shapes, blueprint grid, and ambient glow.
struct ProjectVisualCard: View {
    let category: String
    let iconName: String?
    var height: CGFloat = 140
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                )
                .shadow(color: AppShadow.subtleColor, radius: 10, x: 0, y: 3)
            
            // Subdued Circuit Blueprint Grid Lines Pattern
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                Path { path in
                    // Horizontal grid line
                    path.move(to: CGPoint(x: 20, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w - 20, y: h * 0.5))
                    
                    // Vertical grid lines
                    path.move(to: CGPoint(x: w * 0.28, y: 20))
                    path.addLine(to: CGPoint(x: w * 0.28, y: h - 20))
                    
                    path.move(to: CGPoint(x: w * 0.72, y: 20))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h - 20))
                }
                .stroke(Color.primary.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            
            // Subtle Ambient Glow Behind Icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.glowPrimary.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 48
                    )
                )
                .frame(width: 96, height: 96)
            
            // Central Component Visual
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.iconBadgeGradientStart.opacity(0.18), AppColors.iconBadgeGradientEnd.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    Image(systemName: iconName ?? "cpu")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                            )
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
