//
//  AuthChoiceView.swift
//  AssembleAI
//

import SwiftUI

/// Authentication options screen providing Sign in with Apple, Email, and Guest access.
struct AuthChoiceView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var contentVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: AppSpacing.mdSm) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 34, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.assembleBrandPrimary)
                }
                .opacity(contentVisible ? 1 : 0)
                .scaleEffect(contentVisible ? 1 : 0.9)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Account Access")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Sign in to synchronize assembly projects across your Apple devices, or continue locally.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 10)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: AppSpacing.mdSm) {
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
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.xs)
                .accessibilityLabel("Continue without an account")
                .accessibilityHint("Your data will stay on this device only")
            }
            .padding(.bottom, AppSpacing.xl)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 16)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)) {
                contentVisible = true
            }
        }
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
