//
//  EmailSignInView.swift
//  AssembleAI
//

import SwiftUI

/// Email Sign In screen with validation, keyboard management, and error handling adhering to Apple HIG.
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
            AppColors.groupedBackground.ignoresSafeArea()
            
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
                    .offset(y: contentAppeared ? 0 : 8)
                    
                    // Form Fields Card
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
                                    .foregroundColor(.assembleBrandPrimary)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .padding(.top, AppSpacing.xxs)
                            .accessibilityLabel("Forgot password")
                        }
                    }
                    .appCard()
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)
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
                    .padding(.top, AppSpacing.xs)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.18), value: contentAppeared)
                    
                    // Create Account Secondary CTA
                    Button(action: {
                        router.navigateToCreateAccount()
                    }) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(AppColors.secondaryText)
                            Text("Create account")
                                .fontWeight(.semibold)
                                .foregroundColor(.assembleBrandPrimary)
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .padding(.top, AppSpacing.xs)
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
        .sheet(isPresented: $authService.showErrorSheet) {
            AuthenticationErrorView(
                errorMessage: authService.authErrorMessage,
                onRetry: {
                    authService.showErrorSheet = false
                    handleSignIn()
                },
                onCreateAccount: {
                    authService.showErrorSheet = false
                    router.navigateToCreateAccount()
                },
                onDismiss: {
                    authService.showErrorSheet = false
                }
            )
        }
    }
    
    private var isFormInvalid: Bool {
        email.trimmingCharacters(in: .whitespaces).isEmpty ||
        password.isEmpty
    }
    
    private func validateForm() -> Bool {
        var isValid = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        if trimmedEmail.isEmpty {
            emailError = "Email is required"
            isValid = false
        } else if !isValidEmail(trimmedEmail) {
            emailError = "Please enter a valid email address"
            isValid = false
        } else {
            emailError = nil
        }
        
        if password.isEmpty {
            passwordError = "Password is required"
            isValid = false
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
            isValid = false
        } else {
            passwordError = nil
        }
        
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
    
    private func handleSignIn() {
        hasSubmitted = true
        guard validateForm() else { return }
        
        Task {
            let success = await authService.signIn(email: email, password: password)
            if success {
                router.transitionToHome()
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
