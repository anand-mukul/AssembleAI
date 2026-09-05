//
//  TermsOfServiceSheet.swift
//  AssembleAI
//

import SwiftUI

/// In-app Terms of Service & Safety Guidelines sheet fulfilling App Store compliance without relying on external web hosting.
struct TermsOfServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Header Graphic & Titles
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(Color.assembleBrandPrimary)
                }
                .padding(.top, AppSpacing.sm)
                
                VStack(spacing: 6) {
                    Text("Terms & Safety Guidelines")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .singleLineAdaptive(minScale: 0.85)
                    
                    Text("Important terms and physical safety advisory for AssembleAI.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .adaptiveMultiline(alignment: .center)
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            // Terms Bullet Points Card
            VStack(spacing: AppSpacing.md) {
                termsTile(
                    icon: "bolt.shield.fill",
                    title: "Physical Hardware Safety",
                    description: "Always disconnect power supplies, wear ESD protection, and confirm circuit polarity before energizing."
                )
                
                Divider()
                    .background(AppColors.borderSubtle.opacity(0.5))
                
                termsTile(
                    icon: "eye.fill",
                    title: "AI Guidance Advisory",
                    description: "Vision models assist placement checks, but final circuit safety verification remains the builder's responsibility."
                )
                
                Divider()
                    .background(AppColors.borderSubtle.opacity(0.5))
                
                termsTile(
                    icon: "lock.shield.fill",
                    title: "Data Ownership",
                    description: "All telemetry and assembly logs belong to you, preserved on-device with zero unsolicited data broker sharing."
                )
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer(minLength: AppSpacing.xs)
            
            // Dismiss Action
            PrimaryButton(title: "I Understand", iconName: "checkmark") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if let onContinue = onContinue {
                    onContinue()
                } else {
                    dismiss()
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.top, AppSpacing.md)
        .background(AppColors.appBackground.ignoresSafeArea())
        .presentationDetents([.height(540)])
        .presentationDragIndicator(.visible)
    }
    
    private func termsTile(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(Color.assembleBrandPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.assembleBrandPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .adaptiveMultiline()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Terms Sheet") {
    TermsOfServiceSheet()
}
