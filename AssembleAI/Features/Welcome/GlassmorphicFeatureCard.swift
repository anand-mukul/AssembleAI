//
//  GlassmorphicFeatureCard.swift
//  AssembleAI
//

import SwiftUI

/// Reusable feature highlight card featuring Apple Settings squircle icon badge and clear typography.
struct GlassmorphicFeatureCard: View {
    let iconName: String
    let title: String
    let subtitle: String
    var iconColor: Color = AppColors.badgeBlue
    var showDisclosure: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            SemanticIconBadge(iconName: iconName, size: 32, iconSize: 16, color: iconColor)
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    if showDisclosure {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(iconColor)
                    }
                }
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(2)
                    .adaptiveMultiline()
            }
            
            Spacer(minLength: 0)
            
            if showDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.tertiaryText)
                    .padding(.top, 4)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Glassmorphic Feature Card") {
    ZStack {
        AppColors.groupedBackground.ignoresSafeArea()
        VStack(spacing: 12) {
            GlassmorphicFeatureCard(
                iconName: "viewfinder",
                title: "Live Guidance",
                subtitle: "Follows your hands as you build and highlights where each component connects.",
                iconColor: AppColors.badgeBlue
            )
            GlassmorphicFeatureCard(
                iconName: "checkmark.seal",
                title: "Physical Verification",
                subtitle: "Confirms pin positions, wire rows, and polarities before you power on.",
                iconColor: AppColors.badgeGreen
            )
            GlassmorphicFeatureCard(
                iconName: "lock.shield",
                title: "Private & On-Device",
                subtitle: "All camera processing stays strictly on your iPhone. Zero cloud uploads.",
                iconColor: AppColors.badgeIndigo,
                showDisclosure: true
            )
        }
        .padding()
    }
}
