//
//  AuthenticationErrorView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Native-styled error alert view for handling authentication failures gracefully.
struct AuthenticationErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    @State private var iconAppeared = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Drag indicator
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            Spacer()
            
            VStack(spacing: AppSpacing.mdSm) {
                ZStack {
                    Circle()
                        .fill(AppColors.error.opacity(0.1))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(AppColors.error)
                        .scaleEffect(iconAppeared ? 1 : 0.7)
                }
                
                Text("Something went wrong")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(errorMessage.isEmpty ? "We couldn't complete sign in. Please try again." : errorMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            
            Spacer()
            
            VStack(spacing: AppSpacing.mdSm) {
                PrimaryButton(title: "Try Again", iconName: "arrow.clockwise") {
                    onRetry()
                }
                
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                iconAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(errorMessage.isEmpty ? "Sign in failed" : errorMessage)")
    }
}

#Preview("Authentication Error View") {
    AuthenticationErrorView(
        errorMessage: "Invalid email or password. Please try again.",
        onRetry: {},
        onDismiss: {}
    )
}
