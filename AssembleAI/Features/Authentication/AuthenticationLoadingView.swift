//
//  AuthenticationLoadingView.swift
//  AssembleAI
//

import SwiftUI

/// Lightweight loading overlay view for smooth authentication transition states.
struct AuthenticationLoadingView: View {
    var message: String = "Signing you in…"
    
    var body: some View {
        ZStack {
            AppColors.appBackground.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.assembleBrandPrimary)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview("Authentication Loading View") {
    AuthenticationLoadingView()
}
