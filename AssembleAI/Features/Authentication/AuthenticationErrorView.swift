//
//  AuthenticationErrorView.swift
//  AssembleAI
//

import SwiftUI

/// Native-styled error alert view for handling authentication failures gracefully.
struct AuthenticationErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(AppColors.error)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(errorMessage.isEmpty ? "We couldn't complete sign in. Please try again." : errorMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            Spacer()
            
            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Try Again", iconName: "arrow.clockwise") {
                    onRetry()
                }
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColors.appBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

#Preview("Authentication Error View") {
    AuthenticationErrorView(
        errorMessage: "Invalid email or password. Please try again.",
        onRetry: {},
        onDismiss: {}
    )
}
