//
//  MockAuthenticationService.swift
//  AssembleAI
//

import Foundation
import SwiftUI
import Combine

/// In-memory mock implementation of AuthenticationService for development and prototype testing.
@MainActor
final class MockAuthenticationService: AuthenticationService {
    @Published private(set) var currentUser: User? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var authError: String? = nil
    
    // Allows testing forced failure modes in previews or UI tests
    var shouldFailNextOperation: Bool = false
    var customFailureMessage: String? = nil
    
    init(initialUser: User? = nil) {
        if let initialUser = initialUser {
            self.currentUser = initialUser
            self.isAuthenticated = true
        }
    }
    
    func signInWithApple() async throws {
        isLoading = true
        authError = nil
        
        // Simulate network/security delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        if shouldFailNextOperation {
            isLoading = false
            let message = customFailureMessage ?? "Sign in with Apple failed. Please try again."
            authError = message
            throw AuthError.serviceError(message)
        }
        
        let user = User(
            id: UUID().uuidString,
            name: "Alex Morgan",
            email: "alex.morgan@icloud.com",
            provider: .apple,
            createdAt: Date()
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        self.isLoading = false
    }
    
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        let user = User(
            id: userId,
            name: name ?? "Alex Morgan",
            email: email ?? "alex.morgan@icloud.com",
            provider: .apple,
            createdAt: Date()
        )
        
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        try await Task.sleep(nanoseconds: 1_200_000_000)
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Allow trigger for error testing with specific email
        if trimmedEmail == "error@assembleai.com" || shouldFailNextOperation {
            isLoading = false
            let message = customFailureMessage ?? "Invalid email or password. Please verify your credentials."
            authError = message
            throw AuthError.invalidCredentials
        }
        
        let user = User(
            id: UUID().uuidString,
            name: "Assemble Builder",
            email: trimmedEmail,
            provider: .email,
            createdAt: Date()
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        self.isLoading = false
    }
    
    func createAccount(name: String, email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        try await Task.sleep(nanoseconds: 1_400_000_000)
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedEmail == "exists@assembleai.com" || shouldFailNextOperation {
            isLoading = false
            let message = customFailureMessage ?? "An account with this email address already exists."
            authError = message
            throw AuthError.accountAlreadyExists
        }
        
        let user = User(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            email: trimmedEmail,
            provider: .email,
            createdAt: Date()
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        self.isLoading = false
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        authError = nil
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        if shouldFailNextOperation {
            isLoading = false
            let message = customFailureMessage ?? "Unable to send password reset email right now."
            authError = message
            throw AuthError.serviceError(message)
        }
        
        self.isLoading = false
    }
    
    func continueAsGuest() async {
        isLoading = true
        authError = nil
        
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        let guestUser = User(
            id: UUID().uuidString,
            name: "Guest",
            email: nil,
            provider: .guest,
            createdAt: Date()
        )
        
        self.currentUser = guestUser
        self.isAuthenticated = true
        self.isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.isLoading = false
        self.authError = nil
    }
    
    func clearError() {
        authError = nil
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case accountAlreadyExists
    case serviceError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .accountAlreadyExists:
            return "An account with this email already exists."
        case .serviceError(let message):
            return message
        }
    }
}
