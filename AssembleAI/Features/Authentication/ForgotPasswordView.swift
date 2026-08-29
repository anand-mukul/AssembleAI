//
//  ForgotPasswordView.swift
//  AssembleAI
//

import SwiftUI

/// Password reset request view with simulated success state.
struct ForgotPasswordView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    
    @State private var email: String = ""
    @State private var emailError: String? = nil
    @State private var hasSubmitted: Bool = false
    @State private var isSuccessState: Bool = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            if isSuccessState {
                successStateView
            } else {
                requestStateView
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var requestStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: AppSpacing.md)
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Reset your password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Enter your email and we'll send instructions to reset it.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Email Input
            CustomTextField(
                title: "Email",
                placeholder: "name@example.com",
                text: $email,
                iconName: "envelope",
                errorMessage: emailError,
                keyboardType: .emailAddress,
                submitLabel: .send,
                onCommit: handleSendResetLink
            )
            
            // Primary Button
            PrimaryButton(
                title: "Send Reset Link",
                iconName: "paperplane.fill",
                isLoading: authService.isLoading,
                isDisabled: email.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                handleSendResetLink()
            }
            .padding(.top, AppSpacing.xs)
            
            // Cancel Button
            Button(action: {
                router.pop()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var successStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "envelope.badge.shield.halffilled")
                    .font(.system(size: 56))
                    .foregroundColor(.assembleBrandPrimary)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Check your inbox")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("If an account exists for \(email), you'll receive reset instructions shortly.")
                    .font(.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            
            Spacer()
            
            PrimaryButton(title: "Done") {
                router.pop()
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    private func handleSendResetLink() {
        hasSubmitted = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedEmail.isEmpty else {
            emailError = "Enter your email address."
            return
        }
        
        guard isValidEmail(trimmedEmail) else {
            emailError = "Enter a valid email address."
            return
        }
        
        emailError = nil
        
        Task {
            do {
                try await authService.resetPassword(email: trimmedEmail)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSuccessState = true
                }
            } catch {
                // Handled via authService error state
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

#Preview("Forgot Password View") {
    NavigationView {
        ForgotPasswordView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
