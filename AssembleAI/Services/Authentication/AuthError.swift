//
//  AuthError.swift
//  AssembleAI
//

import Foundation

/// Strongly typed authentication error domain for AssembleAI.
enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case invalidEmail
    case weakPassword
    case accountAlreadyExists
    case userNotFound
    case networkError(String)
    case networkUnavailable
    case serviceError(String)
    case appleSignInFailed(String)
    case userCancelled
    case unauthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please verify your credentials."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters long."
        case .accountAlreadyExists:
            return "An account with this email already exists. Please sign in instead."
        case .userNotFound:
            return "Incorrect email or password. Please verify your credentials and try again, or create a new account."
        case .networkError(let message):
            return message
        case .networkUnavailable:
            return "Unable to reach the authentication server. Please check your internet connection and try again."
        case .serviceError(let message):
            return message
        case .appleSignInFailed(let message):
            return "Apple Sign-in failed: \(message)"
        case .userCancelled:
            return "Authentication was cancelled."
        case .unauthenticated:
            return "You are not signed in."
        }
    }
}
