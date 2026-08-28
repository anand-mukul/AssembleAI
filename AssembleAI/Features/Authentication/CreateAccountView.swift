//
//  CreateAccountView.swift
//  AssembleAI
//

import SwiftUI

/// Create Account screen with full field validation and accessibility labels.
struct CreateAccountView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: CloudKitAuthService
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var nameError: String? = nil
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var confirmPasswordError: String? = nil
    @State private var hasSubmitted: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header
                VStack(spacing: AppSpacing.xs) {
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Sync your assembly projects and history safely.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)
                
                // Form Fields
                VStack(spacing: AppSpacing.md) {
                    CustomTextField(
                        title: "Full Name",
                        placeholder: "Alex Morgan",
                        text: $name,
                        iconName: "person",
                        errorMessage: nameError,
                        keyboardType: .namePhonePad,
                        submitLabel: .next
                    )
                    .onChange(of: name) {
                        if hasSubmitted { validateForm() }
                    }
                    
                    CustomTextField(
                        title: "Email Address",
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
                    
                    CustomTextField(
                        title: "Password",
                        placeholder: "At least 8 characters",
                        text: $password,
                        iconName: "lock",
                        isSecure: true,
                        errorMessage: passwordError,
                        submitLabel: .next
                    )
                    .onChange(of: password) {
                        if hasSubmitted { validateForm() }
                    }
                    
                    CustomTextField(
                        title: "Confirm Password",
                        placeholder: "Re-enter password",
                        text: $confirmPassword,
                        iconName: "lock.shield",
                        isSecure: true,
                        errorMessage: confirmPasswordError,
                        submitLabel: .done,
                        onCommit: handleCreateAccount
                    )
                    .onChange(of: confirmPassword) {
                        if hasSubmitted { validateForm() }
                    }
                }
                
                // Primary Action Button
                PrimaryButton(
                    title: "Create Account",
                    iconName: "checkmark.circle.fill",
                    isLoading: authService.isLoading,
                    isDisabled: isFormIncomplete
                ) {
                    handleCreateAccount()
                }
                .padding(.top, AppSpacing.sm)
                
                // Navigation to Sign In
                Button(action: {
                    router.pop()
                }) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(AppColors.secondaryText)
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.assembleBrandPrimary)
                    }
                    .font(.subheadline)
                }
                .padding(.top, AppSpacing.md)
                .accessibilityLabel("Already have an account? Sign In")
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isFormIncomplete: Bool {
        return name.trimmingCharacters(in: .whitespaces).isEmpty ||
               email.trimmingCharacters(in: .whitespaces).isEmpty ||
               password.isEmpty ||
               confirmPassword.isEmpty
    }
    
    @discardableResult
    private func validateForm() -> Bool {
        var isValid = true
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            nameError = "Enter your full name."
            isValid = false
        } else {
            nameError = nil
        }
        
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
            passwordError = "Enter a password."
            isValid = false
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters."
            isValid = false
        } else {
            passwordError = nil
        }
        
        if confirmPassword.isEmpty {
            confirmPasswordError = "Confirm your password."
            isValid = false
        } else if confirmPassword != password {
            confirmPasswordError = "Passwords do not match."
            isValid = false
        } else {
            confirmPasswordError = nil
        }
        
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func handleCreateAccount() {
        hasSubmitted = true
        guard validateForm() else { return }
        
        Task {
            do {
                try await authService.createAccount(name: name, email: email, password: password)
                router.transitionToHome()
            } catch {
                // Auth error captured by authService
            }
        }
    }
}

#Preview("Create Account View") {
    NavigationView {
        CreateAccountView()
            .environmentObject(AppRouter())
            .environmentObject(CloudKitAuthService())
    }
}
