//
//  AuthenticationService.swift
//  AssembleAI
//

import Foundation
import Combine

/// Protocol defining the authentication service contract.
/// Concrete implementations handle backend interactions or mock operations.
@MainActor
protocol AuthenticationService: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var authError: String? { get set }
    
    func signInWithApple() async throws
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws
    func signInWithAppleCredential(userId: String, name: String?, email: String?, idToken: String?) async throws
    func signIn(email: String, password: String) async throws
    func createAccount(name: String, email: String, password: String) async throws
    func resetPassword(email: String) async throws
    func continueAsGuest() async
    func signOut() async
    func deleteAccount() async throws
    func clearError()
}

extension AuthenticationService {
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws {
        try await signInWithAppleCredential(userId: userId, name: name, email: email, idToken: nil)
    }
}
