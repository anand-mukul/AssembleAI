//
//  AppRouter.swift
//  AssembleAI
//

import SwiftUI
import Combine

/// Supported application navigation routes.
enum AppRoute: Hashable, Identifiable {
    case launch
    case welcome
    case authChoice
    case signInWithApple
    case signIn
    case createAccount
    case forgotPassword
    case home
    case camera(AssemblyStep)
    case analyzing(AssemblyStep)
    
    var id: String {
        switch self {
        case .launch: return "launch"
        case .welcome: return "welcome"
        case .authChoice: return "authChoice"
        case .signInWithApple: return "signInWithApple"
        case .signIn: return "signIn"
        case .createAccount: return "createAccount"
        case .forgotPassword: return "forgotPassword"
        case .home: return "home"
        case .camera(let step): return "camera_\(step.id.uuidString)"
        case .analyzing(let step): return "analyzing_\(step.id.uuidString)"
        }
    }
}

/// Centralized router managing root view state, navigation path, and sheets.
@MainActor
final class AppRouter: ObservableObject {
    @Published var rootRoute: AppRoute = .launch
    @Published var navigationPath = NavigationPath()
    @Published var showGuestConfirmationSheet: Bool = false
    
    func completeLaunch(isAuthenticated: Bool) {
        withAnimation(.easeInOut(duration: 0.35)) {
            if isAuthenticated {
                rootRoute = .home
            } else {
                rootRoute = .welcome
            }
        }
    }
    
    func navigateToAuthChoice() {
        withAnimation(.easeInOut(duration: 0.25)) {
            rootRoute = .authChoice
        }
    }
    
    func navigateToSignInWithApple() {
        if rootRoute == .authChoice {
            navigationPath.append(AppRoute.signInWithApple)
        } else {
            rootRoute = .authChoice
            navigationPath.append(AppRoute.signInWithApple)
        }
    }
    
    func navigateToSignIn() {
        if rootRoute == .authChoice {
            navigationPath.append(AppRoute.signIn)
        } else {
            rootRoute = .authChoice
            navigationPath.append(AppRoute.signIn)
        }
    }
    
    func navigateToEmailSignIn() {
        navigateToSignIn()
    }
    
    func navigateToCreateAccount() {
        navigationPath.append(AppRoute.createAccount)
    }
    
    func navigateToForgotPassword() {
        navigationPath.append(AppRoute.forgotPassword)
    }
    
    func navigateToCamera(step: AssemblyStep) {
        navigationPath.append(AppRoute.camera(step))
    }
    
    func navigateToAnalyzing(step: AssemblyStep) {
        navigationPath.append(AppRoute.analyzing(step))
    }
    
    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func popToAuthChoice() {
        navigationPath = NavigationPath()
        rootRoute = .authChoice
    }
    
    func transitionToHome() {
        navigationPath = NavigationPath()
        withAnimation(.easeInOut(duration: 0.35)) {
            rootRoute = .home
        }
    }
    
    func transitionToWelcome() {
        navigationPath = NavigationPath()
        withAnimation(.easeInOut(duration: 0.35)) {
            rootRoute = .welcome
        }
    }
}
