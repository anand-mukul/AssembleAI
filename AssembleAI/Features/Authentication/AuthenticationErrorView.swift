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
    
    @State private var contentAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()
            
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 8)
                
                // Animated Error Icon
                AnimatedHeaderIcon(
                    iconName: "exclamationmark.triangle.fill",
                    iconSize: 34,
                    circleDiameter: 76,
                    useGradient: false,
                    staticColor: AppColors.error
                )
                
                // Error Details Card
                VStack(spacing: AppSpacing.sm) {
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
                }
                .appCard()
                .padding(.horizontal, AppSpacing.screenEdge)
                
                Spacer(minLength: 10)
                
                // Actions
                VStack(spacing: AppSpacing.sm) {
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
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.md)
            }
        }
        .presentationDetents([.height(480), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                contentAppeared = true
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
