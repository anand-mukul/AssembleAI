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
        VStack(spacing: 0) {
            // Header: Generous breathing space below modal grabber + strictly centered icon & title
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "doc.text.fill",
                    iconSize: 34,
                    circleDiameter: 68,
                    staticColor: AppColors.badgeBlue
                )
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Terms & Safety Guidelines")
                        .font(.title2)
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
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 28)
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
            
            // Terms Bullet Points Card
            VStack(spacing: 0) {
                termsTile(
                    icon: "bolt.shield.fill",
                    title: "Physical Hardware Safety",
                    description: "Always disconnect power supplies, wear ESD protection, and confirm circuit polarity before energizing.",
                    color: AppColors.badgeOrange
                )
                
                Divider()
                    .padding(.leading, 62)
                
                termsTile(
                    icon: "eye.fill",
                    title: "AI Guidance Advisory",
                    description: "Vision models assist placement checks, but final circuit safety verification remains the builder's responsibility.",
                    color: AppColors.badgeBlue
                )
                
                Divider()
                    .padding(.leading, 62)
                
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
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer(minLength: AppSpacing.md)
            
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
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .presentationDetents([.height(530)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
    }
    
    private func termsTile(icon: String, title: String, description: String, color: Color) -> some View {
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

#Preview("Terms Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            TermsOfServiceSheet()
        }
}
