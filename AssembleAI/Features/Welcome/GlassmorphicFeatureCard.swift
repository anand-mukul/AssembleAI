//
//  GlassmorphicFeatureCard.swift
//  AssembleAI
//

import SwiftUI

/// Reusable glassmorphic feature capsule with gradient icon badge, used on the Welcome screen
/// and any other location needing premium feature highlight cards.
struct GlassmorphicFeatureCard: View {
    let iconName: String
    let title: String
    let subtitle: String
    var showDisclosure: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            GradientIconBadge(iconName: iconName)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    if showDisclosure {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
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
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
        )
        .shadow(color: AppShadow.subtleColor, radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Glassmorphic Feature Card") {
    ZStack {
        GradientAtmosphereBackground(intensity: .hero)
        VStack(spacing: 12) {
            GlassmorphicFeatureCard(
                iconName: "viewfinder",
                title: "Live Guidance",
                subtitle: "Follows your hands as you build and highlights where each component connects."
            )
            GlassmorphicFeatureCard(
                iconName: "checkmark.seal",
                title: "Physical Verification",
                subtitle: "Confirms pin positions, wire rows, and polarities before you power on."
            )
            GlassmorphicFeatureCard(
                iconName: "lock.shield",
                title: "Private & On-Device",
                subtitle: "All camera processing stays strictly on your iPhone. Zero cloud uploads.",
                showDisclosure: true
            )
        }
        .padding()
    }
}
