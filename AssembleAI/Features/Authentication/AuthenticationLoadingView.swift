//
//  AuthenticationLoadingView.swift
//  AssembleAI
//

import SwiftUI

/// Lightweight loading overlay view for smooth authentication transition states adhering to Apple HIG.
struct AuthenticationLoadingView: View {
    var message: String = "Signing you in…"
    
    var body: some View {
        ZStack {
            // Atmospheric dimmed backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Native Modal HUD
            VStack(spacing: AppSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.assembleBrandPrimary)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: AppShadow.mediumColor, radius: 20, x: 0, y: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview("Authentication Loading View") {
    AuthenticationLoadingView()
}
