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
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero Illustration Header
                VStack(spacing: AppSpacing.mdSm) {
                    AnimatedHeaderIcon(
                        iconName: "apple.logo",
                        iconSize: 38,
                        circleDiameter: 80,
                        useGradient: false,
                        staticColor: AppColors.primaryText
                    )
                    
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
                            .frame(height: AppSpacing.buttonHeight)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignInCompletion(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: AppSpacing.buttonHeight)
                        .clipShape(Capsule(style: .continuous))
                        .accessibilityLabel("Sign in with Apple")
                    }
                    
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
                    .padding(.vertical, AppSpacing.xs)
                }
                .padding(.bottom, AppSpacing.xl)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 16)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign in with Apple", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
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
                    let idTokenString = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                    
                    do {
                        try await authService.signInWithAppleCredential(
                            userId: userIdentifier,
                            name: fullName.isEmpty ? nil : fullName,
                            email: email,
                            idToken: idTokenString
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
    NavigationStack {
        SignInWithAppleView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
