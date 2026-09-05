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
    var onCreateAccount: (() -> Void)? = nil
    let onDismiss: () -> Void
    
    @State private var iconAppeared = false
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 8)
            
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.error.opacity(0.1))
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(AppColors.error)
                        .scaleEffect(iconAppeared ? 1 : 0.7)
                }
                .padding(.bottom, AppSpacing.xxs)
                
                Text("Unable to Sign In")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Text(errorMessage.isEmpty ? "Incorrect email or password. Please verify your credentials and try again." : errorMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.sm)
            }
            
            Spacer(minLength: 10)
            
            VStack(spacing: AppSpacing.xs) {
                PrimaryButton(title: "Try Again", iconName: "arrow.clockwise") {
                    onRetry()
                }
                
                if let onCreateAccount = onCreateAccount {
                    SecondaryButton(title: "Create an Account", iconName: "person.badge.plus") {
                        onCreateAccount()
                    }
                }
                
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.bottom, AppSpacing.md)
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
