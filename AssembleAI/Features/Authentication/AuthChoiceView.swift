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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                    .padding(.top, AppSpacing.xl)
                
                VStack(spacing: AppSpacing.md) {
                    TrustRow(iconName: "lock.shield", title: "Private by default", subtitle: "Guest projects stay on this device until you choose to sync.")
                    TrustRow(iconName: "icloud.and.arrow.up", title: "Sync when signed in", subtitle: "Use an account to keep project history available across sessions.")
                    TrustRow(iconName: "key", title: "Secure credentials", subtitle: "Authentication state is stored with the system keychain.")
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, 176)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.assembleBrandPrimary)
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Choose how to continue")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Sign in for cloud sync, or stay local and start building without creating an account.")
                    .font(.body)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var bottomActions: some View {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Continue without account")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(.regularMaterial)
    }
}

private struct TrustRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
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
