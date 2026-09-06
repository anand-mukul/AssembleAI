//
//  PrivacySheet.swift
//  AssembleAI
//

import SwiftUI

/// Pre-camera privacy disclosure sheet explaining on-device image processing and local pseudonymous telemetry logging.
struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Header Graphic & Titles
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "lock.shield.fill",
                    iconSize: 32,
                    circleDiameter: 64,
                    staticColor: AppColors.badgeGreen
                )
                .padding(.top, AppSpacing.sm)
                
                VStack(spacing: 4) {
                    Text("Your Camera, Your Data")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("AssembleAI processes visual information locally on your device.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .adaptiveMultiline()
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            // Privacy Bullet Points Card
            VStack(spacing: 0) {
                privacyTile(
                    icon: "cpu.fill",
                    title: "On-Device Visual Intelligence",
                    description: "Apple Vision and local state estimators process captured frames on your device.",
                    color: AppColors.badgeBlue
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                privacyTile(
                    icon: "icloud.slash.fill",
                    title: "No Camera Image Uploads",
                    description: "Camera frames are analyzed locally in memory and never transmitted to cloud servers.",
                    color: AppColors.badgeGreen
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                privacyTile(
                    icon: "hand.raised.fill",
                    title: "Pseudonymous Research Data",
                    description: "Session timing metrics use randomly generated IDs without personal identifiers.",
                    color: AppColors.badgeIndigo
                )
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer(minLength: 16)
            
            PrimaryButton(title: "Continue") {
                dismiss()
                onContinue()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.md)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .presentationDetents([.height(520), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
    }
    
    private func privacyTile(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            SemanticIconBadge(iconName: icon, size: 30, iconSize: 15, color: color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(2)
                    .adaptiveMultiline()
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
    }
}

#Preview("Privacy Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            PrivacySheet(onContinue: {})
        }
}
