//
//  SignInWithAppleView.swift
//  AssembleAI
//

import SwiftUI
import AuthenticationServices

/// Dedicated Sign In with Apple view adhering strictly to Apple design guidelines.
struct SignInWithAppleView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: CloudKitAuthService
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            // Header
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "applelogo")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(AppColors.primaryText)
                
                Text("Sign in")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Continue with Apple to access your projects.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            Spacer()
            
            // Sign in with Apple Button
            VStack(spacing: AppSpacing.md) {
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            do {
                                try await authService.signInWithApple()
                                router.transitionToHome()
                            } catch {
                                // Error handled in authService state
                            }
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(14)
                .padding(.horizontal, AppSpacing.lg)
                
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2)
                    Text("Your account stays private.")
                        .font(.caption)
                }
                .foregroundColor(AppColors.secondaryText)
                
                Button(action: {
                    router.pop()
                }) {
                    Text("Not now")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
}

#Preview("Sign In With Apple") {
    SignInWithAppleView()
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}
