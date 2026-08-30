//
//  AuthChoiceView.swift
//  AssembleAI
//

import SwiftUI
import AuthenticationServices

/// Authentication options screen providing native Sign in with Apple, Email, and Guest access.
@MainActor
struct AuthChoiceView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var contentVisible = false
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
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
                if isProcessing {
                    ProgressView("Authenticating...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(height: 50)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignInCompletion(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .accessibilityLabel("Sign in with Apple")
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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
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
        .alert("Sign in with Apple", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)) {
                contentVisible = true
            }
        }
    }
    
    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        isProcessing = true
        Task {
            switch result {
            case .success(let authorization):
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    let userIdentifier = appleIDCredential.user
                    let fullName = [
                        appleIDCredential.fullName?.givenName,
                        appleIDCredential.fullName?.familyName
                    ].compactMap { $0 }.joined(separator: " ")
                    let email = appleIDCredential.email
                    
                    do {
                        try await authService.signInWithAppleCredential(
                            userId: userIdentifier,
                            name: fullName.isEmpty ? nil : fullName,
                            email: email
                        )
                        isProcessing = false
                        router.transitionToHome()
                    } catch {
                        isProcessing = false
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                } else {
                    do {
                        try await authService.signInWithApple()
                        isProcessing = false
                        router.transitionToHome()
                    } catch {
                        isProcessing = false
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            case .failure(let error):
                isProcessing = false
                let nsError = error as NSError
                if nsError.code != 1001 {
                    errorMessage = "Apple authentication failed: \(error.localizedDescription)"
                    showErrorAlert = true
                }
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
