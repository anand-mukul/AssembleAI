//
//  MainContainerView.swift
//  AssembleAI
//

import SwiftUI

/// Main container view orchestrating top-level routing, modal overlays, and sheet presentations.
struct MainContainerView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    
    var body: some View {
        ZStack {
            switch router.rootRoute {
            case .launch:
                LaunchView()
                    .transition(.opacity)
                
            case .welcome:
                NavigationStack(path: $router.navigationPath) {
                    WelcomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .transition(.opacity)
                
            case .authChoice:
                NavigationStack(path: $router.navigationPath) {
                    AuthChoiceView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .transition(.opacity)
                
            case .home:
                MainTabView()
                    .transition(.opacity)
                
            default:
                NavigationStack(path: $router.navigationPath) {
                    AuthChoiceView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
            }
            
            // Authentication Loading Overlay
            if authService.isLoading {
                AuthenticationLoadingView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        // Guest Confirmation Sheet
        .sheet(isPresented: $router.showGuestConfirmationSheet) {
            ContinueWithoutAccountSheet()
        }
        // Global Authentication Error Presentation
        .sheet(isPresented: Binding(
            get: { authService.authError != nil },
            set: { if !$0 { authService.clearError() } }
        )) {
            if let errorMsg = authService.authError {
                AuthenticationErrorView(
                    errorMessage: errorMsg,
                    onRetry: {
                        authService.clearError()
                    },
                    onCreateAccount: {
                        authService.clearError()
                        router.navigateToCreateAccount()
                    },
                    onDismiss: {
                        authService.clearError()
                    }
                )
                .presentationDetents([.height(440), .medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: router.rootRoute)
        .animation(.easeInOut(duration: 0.25), value: authService.isLoading)
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .authChoice:
            AuthChoiceView()
        case .signInWithApple:
            SignInWithAppleView()
        case .signIn:
            EmailSignInView()
        case .createAccount:
            CreateAccountView()
        case .forgotPassword:
            ForgotPasswordView()
        case .camera(let step):
            AssemblyCameraView(currentStep: step)
        case .analyzing:
            AnalysisView()
        default:
            EmptyView()
        }
    }
}

#Preview("Main Container View") {
    MainContainerView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}
