//
//  EmailSignInView.swift
//  AssembleAI
//

import SwiftUI

/// Email Sign In screen with validation, keyboard management, and error handling.
struct EmailSignInView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var email: String = ""
    @State private var password: String = ""
    
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var hasSubmitted: Bool = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        AnimatedHeaderIcon(iconName: "envelope.fill", iconSize: 28, circleDiameter: 64)
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("Sign In")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text("Enter your email and password to access your account.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.sm)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)
                    
                    // Form Fields in glassmorphic card
                    VStack(spacing: AppSpacing.md) {
                        CustomTextField(
                            title: "Email",
                            placeholder: "name@example.com",
                            text: $email,
                            iconName: "envelope",
                            errorMessage: emailError,
                            keyboardType: .emailAddress,
                            submitLabel: .next
                        )
                        .onChange(of: email) {
                            if hasSubmitted { validateForm() }
                        }
                        
                        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                            CustomTextField(
                                title: "Password",
                                placeholder: "Enter password",
                                text: $password,
                                iconName: "lock",
                                isSecure: true,
                                errorMessage: passwordError,
                                submitLabel: .done,
                                onCommit: handleSignIn
                            )
                            .onChange(of: password) {
                                if hasSubmitted { validateForm() }
                            }
                            
                            Button(action: {
                                router.navigateToForgotPassword()
                            }) {
                                Text("Forgot password?")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.top, AppSpacing.xxs)
                            .accessibilityLabel("Forgot password")
                        }
                    }
                    .appCard()
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.1), value: contentAppeared)
                    
                    // Primary Action Button
                    PrimaryButton(
                        title: "Sign In",
                        iconName: "arrow.right",
                        isLoading: authService.isLoading,
                        isDisabled: isFormInvalid
                    ) {
                        handleSignIn()
                    }
                    .padding(.top, AppSpacing.sm)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.2), value: contentAppeared)
                    
                    // Create Account Secondary CTA
                    Button(action: {
                        router.navigateToCreateAccount()
                    }) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(AppColors.secondaryText)
                            Text("Create account")
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, AppSpacing.md)
                    .accessibilityLabel("Don't have an account? Create account")
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                contentAppeared = true
            }
        }
    }
    
    private var isFormInvalid: Bool {
        return email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty
    }
    
    @discardableResult
    private func validateForm() -> Bool {
        var isValid = true
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if trimmedEmail.isEmpty {
            emailError = "Enter your email address."
            isValid = false
        } else if !isValidEmail(trimmedEmail) {
            emailError = "Enter a valid email address."
            isValid = false
        } else {
            emailError = nil
        }
        
        if password.isEmpty {
            passwordError = "Enter your password."
            isValid = false
        } else {
            passwordError = nil
        }
        
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func handleSignIn() {
        hasSubmitted = true
        guard validateForm() else { return }
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                router.transitionToHome()
            } catch {
                // Auth error captured by authService.authError
            }
        }
    }
}

#Preview("Email Sign In View") {
    NavigationStack {
        EmailSignInView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
