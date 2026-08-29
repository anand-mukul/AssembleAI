//
//  SignInWithAppleView.swift
//  AssembleAI
//

import SwiftUI
import AuthenticationServices

/// Apple HIG compliant Sign in with Apple screen with full concurrency safety.
struct SignInWithAppleView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Hero Illustration Header
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(AppColors.primaryText)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Sign in with Apple")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Fast, secure, and private authentication. Synchronize your assembly workflows automatically.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            
            Spacer()
            
            // Sign in with Apple Official SwiftUI Button
            VStack(spacing: AppSpacing.md) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignInCompletion(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 52)
                .cornerRadius(12)
                .accessibilityLabel("Sign in with Apple")
                
                Button(action: {
                    router.pop()
                }) {
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
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .success:
                try? await authService.signInWithApple()
                router.transitionToHome()
            case .failure(let error):
                authService.authError = error.localizedDescription
            }
        }
    }
}

#Preview("Sign in with Apple View") {
    NavigationView {
        SignInWithAppleView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
