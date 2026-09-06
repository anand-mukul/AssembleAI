//
//  ForgotPasswordView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Password reset request view with simulated success state.
struct ForgotPasswordView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var email: String = ""
    @State private var emailError: String? = nil
    @State private var hasSubmitted: Bool = false
    @State private var isSuccessState: Bool = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()
            
            VStack(spacing: AppSpacing.lg) {
                if isSuccessState {
                    successStateView
                } else {
                    requestStateView
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                contentAppeared = true
            }
        }
    }
    
    @ViewBuilder
    private var requestStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: AppSpacing.md)
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                AnimatedHeaderIcon(iconName: "key.fill", iconSize: 30, circleDiameter: 68)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Enter your email and we'll send instructions to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            
            // Email Input in glassmorphic card
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
            .appCard()
            .opacity(contentAppeared ? 1 : 0)
            .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.1), value: contentAppeared)
            
            // Primary Button
            PrimaryButton(
                title: "Send Reset Link",
                iconName: "paperplane",
                isLoading: authService.isLoading,
                isDisabled: email.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                handleSendResetLink()
            }
            .padding(.top, AppSpacing.xs)
            .opacity(contentAppeared ? 1 : 0)
            .animation(reduceMotion ? .none : AppAnimation.entranceSpring.delay(0.15), value: contentAppeared)
            
            // Cancel Button
            Button(action: {
                router.pop()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var successStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "envelope.badge.shield.halffilled",
                    iconSize: 34,
                    circleDiameter: 72,
                    useGradient: false,
                    staticColor: AppColors.success
                )
                .padding(.bottom, AppSpacing.xs)
                
                Text("Check Your Inbox")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("If an account exists for \(email), you'll receive reset instructions shortly.")
                    .font(.subheadline)
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
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
