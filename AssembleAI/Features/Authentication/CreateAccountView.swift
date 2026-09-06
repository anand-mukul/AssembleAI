//
//  CreateAccountView.swift
//  AssembleAI
//

import SwiftUI

/// Create Account screen with full field validation and accessibility labels adhering to Apple HIG.
struct CreateAccountView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var nameError: String? = nil
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var confirmPasswordError: String? = nil
    @State private var hasSubmitted: Bool = false
    @State private var showEmailConfirmationAlert: Bool = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        AnimatedHeaderIcon(iconName: "person.badge.plus", iconSize: 28, circleDiameter: 64)
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("Create Account")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text("Create an account to track your hardware assembly progress.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)
                    
                    // Form Fields Card
                    VStack(spacing: AppSpacing.md) {
                        CustomTextField(
                            title: "Full Name",
                            placeholder: "Jane Doe",
                            text: $name,
                            iconName: "person",
                            errorMessage: nameError,
                            keyboardType: .default,
                            submitLabel: .next
                        )
                        .onChange(of: name) {
                            if hasSubmitted { validateForm() }
                        }
                        
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
                        
                        CustomTextField(
                            title: "Password",
                            placeholder: "At least 6 characters",
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
                    .appCard()
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)
                    .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.1), value: contentAppeared)
                    
                    // Primary Action Button
                    PrimaryButton(
                        title: "Create Account",
                        iconName: "checkmark",
                        isLoading: authService.isLoading,
                        isDisabled: isFormIncomplete
                    ) {
                        handleCreateAccount()
                    }
                    .padding(.top, AppSpacing.xs)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.18), value: contentAppeared)
                    
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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .padding(.top, AppSpacing.xs)
                    .accessibilityLabel("Already have an account? Sign In")
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Check Your Email", isPresented: $showEmailConfirmationAlert) {
            Button("Go to Sign In") {
                router.pop()
            }
        } message: {
            Text("We've sent a verification link to \(email). Please confirm your email address, then sign in.")
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                contentAppeared = true
            }
        }
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
            nameError = "Name is required"
            isValid = false
        } else {
            nameError = nil
        }
        
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
        
        if confirmPassword.isEmpty {
            confirmPasswordError = "Please confirm your password"
            isValid = false
        } else if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
            isValid = false
        } else {
            confirmPasswordError = nil
        }
        
        return isValid
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
    
    private func handleCreateAccount() {
        hasSubmitted = true
        guard validateForm() else { return }
        
        Task {
            let success = await authService.signUp(email: email, password: password, name: name)
            if success {
                showEmailConfirmationAlert = true
            }
        }
    }
}

#Preview("Create Account View") {
    NavigationStack {
        CreateAccountView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
