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
        VStack(spacing: AppSpacing.lg) {
            // Header Graphic & Titles
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "doc.text.fill",
                    iconSize: 32,
                    circleDiameter: 64,
                    staticColor: AppColors.badgeBlue
                )
                .padding(.top, AppSpacing.sm)
                
                VStack(spacing: 4) {
                    Text("Terms & Safety Guidelines")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Important terms and physical safety advisory for AssembleAI.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .adaptiveMultiline()
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            // Terms Bullet Points Card
            VStack(spacing: 0) {
                termsTile(
                    icon: "bolt.shield.fill",
                    title: "Physical Hardware Safety",
                    description: "Always disconnect power supplies, wear ESD protection, and confirm circuit polarity before energizing.",
                    color: AppColors.badgeOrange
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                termsTile(
                    icon: "eye.fill",
                    title: "AI Guidance Advisory",
                    description: "Vision models assist placement checks, but final circuit safety verification remains the builder's responsibility.",
                    color: AppColors.badgeBlue
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                termsTile(
                    icon: "lock.shield.fill",
                    title: "Data Ownership",
                    description: "All telemetry and assembly logs belong to you, preserved on-device with zero unsolicited data broker sharing.",
                    color: AppColors.badgeGreen
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
            
            // Dismiss Action
            PrimaryButton(title: "I Understand") {
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
        .padding(.top, AppSpacing.xs)
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
    }
    
    private func termsTile(icon: String, title: String, description: String, color: Color) -> some View {
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

#Preview("Terms Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            TermsOfServiceSheet()
        }
}
