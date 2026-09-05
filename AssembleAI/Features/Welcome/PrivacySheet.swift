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
        VStack(spacing: AppSpacing.md) {
            // Header Graphic & Titles
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(Color.assembleBrandPrimary)
                }
                .padding(.top, AppSpacing.sm)
                
                VStack(spacing: 6) {
                    Text("Your Camera, Your Data")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text("AssembleAI processes visual information locally on your device.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            // Privacy Bullet Points Card
            VStack(spacing: AppSpacing.md) {
                privacyTile(
                    icon: "cpu.fill",
                    title: "On-Device Visual Intelligence",
                    description: "Apple Vision and local state estimators process captured frames on your device."
                )
                
                Divider()
                    .background(AppColors.borderSubtle.opacity(0.5))
                
                privacyTile(
                    icon: "icloud.slash.fill",
                    title: "No Camera Image Uploads",
                    description: "Camera frames are analyzed locally in memory and never transmitted to cloud servers."
                )
                
                Divider()
                    .background(AppColors.borderSubtle.opacity(0.5))
                
                privacyTile(
                    icon: "hand.raised.fill",
                    title: "Pseudonymous Research Data",
                    description: "Session timing metrics use randomly generated IDs without personal identifiers."
                )
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.borderSubtle.opacity(0.4), lineWidth: 0.5)
            )
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.xs)
            
            Spacer(minLength: 16)
            
            PrimaryButton(title: "Continue", iconName: "arrow.right") {
                dismiss()
                onContinue()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .presentationDetents([.height(540), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
    
    private func privacyTile(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.assembleBrandPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.assembleBrandPrimary)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

#Preview("Privacy Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            PrivacySheet(onContinue: {})
        }
}
