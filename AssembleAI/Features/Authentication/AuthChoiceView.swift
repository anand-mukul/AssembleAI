//
//  AuthChoiceView.swift
//  AssembleAI
//

import SwiftUI

/// Authentication options screen providing Sign in with Apple, Email, and Guest access.
struct AuthChoiceView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                }
                .padding(.bottom, AppSpacing.xs)
                
                Text("Account Access")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Sign in to synchronize assembly projects across your Apple devices or continue locally on this device.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Sign in with Apple", iconName: "apple.logo") {
                    router.navigateToSignInWithApple()
                }
                
                SecondaryButton(title: "Continue with Email", iconName: "envelope.fill") {
                    router.navigateToEmailSignIn()
                }
                
                Button(action: {
                    router.showGuestConfirmationSheet = true
                }) {
                    Text("Continue without account")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.xs)
                .accessibilityLabel("Continue without account")
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Auth Choice View") {
    AuthChoiceView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}

#Preview("Auth Choice View - Dark Mode") {
    AuthChoiceView()
        .preferredColorScheme(.dark)
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}
