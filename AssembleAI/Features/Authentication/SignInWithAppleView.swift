//
//  SignInWithAppleView.swift
//  AssembleAI
//

import SwiftUI
import AuthenticationServices

/// Apple HIG compliant Sign in with Apple screen with full concurrency safety and simulator fallback support.
@MainActor
struct SignInWithAppleView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var contentAppeared = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero Illustration Header
            VStack(spacing: AppSpacing.mdSm) {
                ZStack {
                    Circle()
                        .fill(AppColors.secondaryBackground)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "apple.logo")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundColor(AppColors.primaryText)
                }
                .opacity(contentAppeared ? 1 : 0)
                .scaleEffect(contentAppeared ? 1 : 0.85)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Sign in with Apple")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Fast, secure, and private authentication. Synchronize your assembly workflows automatically.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)
            }
            
            Spacer()
            
            // Sign in with Apple Official SwiftUI Button
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
                    .cornerRadius(14)
                    .accessibilityLabel("Sign in with Apple")
                }
                
                Button(action: {
                    router.pop()
                }) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.xl)
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 16)
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
                contentAppeared = true
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
                }
            case .failure(let error):
                isProcessing = false
                let nsError = error as NSError
                // User cancelled error code is 1001 in ASAuthorizationError
                if nsError.code != 1001 {
                    errorMessage = "Sign in with Apple could not be completed: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview("Sign in with Apple View") {
    NavigationView {
        SignInWithAppleView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
