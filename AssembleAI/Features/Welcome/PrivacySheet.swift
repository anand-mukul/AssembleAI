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
            // Drag handle
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            // Header Graphic
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color.assembleBrandPrimary)
            }
            .padding(.top, AppSpacing.sm)
            
            VStack(spacing: AppSpacing.xs) {
                Text("Your Camera, Your Data")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("AssembleAI processes visual information locally on your device.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            
            // Privacy Bullet Points
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                privacyTile(
                    icon: "cpu.fill",
                    title: "On-Device Visual Intelligence",
                    description: "Apple Vision and local state estimators process captured frames on your device."
                )
                privacyTile(
                    icon: "icloud.slash.fill",
                    title: "No Camera Image Uploads",
                    description: "Camera frames are analyzed locally in memory and never transmitted to cloud servers."
                )
                privacyTile(
                    icon: "hand.raised.fill",
                    title: "Pseudonymous Research Data",
                    description: "Session timing metrics use randomly generated IDs without personal identifiers."
                )
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer()
            
            PrimaryButton(title: "Continue", iconName: "arrow.right") {
                dismiss()
                onContinue()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .presentationDetents([.height(520)])
        .presentationCornerRadius(28)
    }
    
    private func privacyTile(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(Color.assembleBrandPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Privacy Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            PrivacySheet(onContinue: {})
        }
}
