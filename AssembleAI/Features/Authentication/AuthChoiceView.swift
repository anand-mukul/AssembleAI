//
//  AuthChoiceView.swift
//  AssembleAI
//

import SwiftUI
import AuthenticationServices

/// Authentication choice screen presenting Apple Sign In, Email options, and Guest access.
struct AuthChoiceView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: CloudKitAuthService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Welcome to AssembleAI")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Your projects stay yours.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.bottom, AppSpacing.xxl)
            
            // Authentication Options
            VStack(spacing: AppSpacing.md) {
                // Native Sign in with Apple Button
                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            do {
                                try await authService.signInWithApple()
                                router.transitionToHome()
                            } catch {
                                // Error handled via authService.authError state
                            }
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(14)
                .accessibilityLabel("Continue with Apple")
                
                // Divider line with text
                HStack {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .padding(.horizontal, AppSpacing.xs)
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1)
                }
                .padding(.vertical, AppSpacing.xs)
                
                // Continue with Email
                SecondaryButton(title: "Continue with Email", iconName: "envelope.fill") {
                    router.navigateToSignIn()
                }
                
                // Guest / Local Access Button
                Button(action: {
                    router.showGuestConfirmationSheet = true
                }) {
                    Text("Continue without account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                        .underline()
                }
                .padding(.top, AppSpacing.sm)
                .accessibilityLabel("Continue without account")
            }
            .padding(.horizontal, AppSpacing.lg)
            
            Spacer()
            
            // Privacy Explanation Footnote
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Text("An account lets you sync projects and history. You can also continue on this device.")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
}

#Preview("Auth Choice View") {
    AuthChoiceView()
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}

#Preview("Auth Choice View - Dark Mode") {
    AuthChoiceView()
        .preferredColorScheme(.dark)
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}
