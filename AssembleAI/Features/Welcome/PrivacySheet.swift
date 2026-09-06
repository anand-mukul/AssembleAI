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
        VStack(spacing: 0) {
            // Header: Generous breathing space below modal grabber + strictly centered icon & title
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "lock.shield.fill",
                    iconSize: 34,
                    circleDiameter: 68,
                    staticColor: AppColors.badgeGreen
                )
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Your Camera, Your Data")
                        .font(.title2)
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
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 28)
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
            
            // Privacy Disclosure Grouped Card
            VStack(spacing: 0) {
                privacyTile(
                    icon: "cpu.fill",
                    title: "On-Device Visual Intelligence",
                    description: "Apple Vision and local state estimators process captured frames on your device.",
                    color: AppColors.badgeBlue
                )
                
                Divider()
                    .padding(.leading, 62)
                
                privacyTile(
                    icon: "icloud.slash.fill",
                    title: "No Camera Image Uploads",
                    description: "Camera frames are analyzed locally in memory and never transmitted to cloud servers.",
                    color: AppColors.badgeGreen
                )
                
                Divider()
                    .padding(.leading, 62)
                
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
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer(minLength: AppSpacing.md)
            
            // Primary Bottom Action
            PrimaryButton(title: "Continue") {
                dismiss()
                onContinue()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .presentationDetents([.height(530)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
    }
    
    private func privacyTile(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 14) {
            SemanticIconBadge(iconName: icon, size: 32, iconSize: 16, color: color)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text(description)
                    .font(.footnote)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(2)
                    .adaptiveMultiline()
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview("Privacy Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            PrivacySheet(onContinue: {})
        }
}
