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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var contentAppeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero Illustration Header
            VStack(spacing: AppSpacing.mdSm) {
                ZStack {
                    Circle()
                        .fill(AppColors.secondaryBackground)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "apple.logo")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundColor(AppColors.primaryText)
                }
                .opacity(contentAppeared ? 1 : 0)
                .scaleEffect(contentAppeared ? 1 : 0.85)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Sign in with Apple")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Fast, secure, and private authentication. Synchronize your assembly workflows automatically.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)
            }
            
            Spacer()
            
            // Sign in with Apple Official SwiftUI Button
            VStack(spacing: AppSpacing.mdSm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignInCompletion(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(14)
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
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 16)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)) {
                contentAppeared = true
            }
        }
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
