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
    case serviceError(String)
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
            return "An account with this email already exists. Please sign in."
        case .userNotFound:
            return "No account found with this email address."
        case .networkError(let message):
            return "Unable to connect: \(message)"
        case .serviceError(let message):
            return message
        case .unauthenticated:
            return "You are not signed in."
        }
    }
}
