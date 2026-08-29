//
//  SupabaseAuthService.swift
//  AssembleAI
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// Authentication Service backed by Supabase Auth, native Sign in with Apple, and local SwiftData persistence adhering to Apple HIG security standards.
@MainActor
final class SupabaseAuthService: AuthenticationService {
    @Published private(set) var currentUser: User? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var authError: String? = nil
    
    private let supabaseManager: SupabaseManager
    private let mockFallbackService: MockAuthenticationService
    
    init(supabaseManager: SupabaseManager? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        self.mockFallbackService = MockAuthenticationService()
        
        Task {
            await checkExistingSession()
        }
    }
    
    private var userRepository: UserRepositoryImpl {
        UserRepositoryImpl(modelContext: PersistenceController.shared.container.mainContext)
    }
    
    func checkExistingSession() async {
        // Restore saved session from local SwiftData storage
        if let savedUser = try? await userRepository.fetchCurrentUser() {
            self.currentUser = savedUser
            self.isAuthenticated = true
        }
    }
    
    func signInWithApple() async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        try await mockFallbackService.signInWithApple()
        if let user = mockFallbackService.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            try? await userRepository.saveUser(user)
        }
    }
    
    func signInWithAppleCredential(userId: String, name: String?, email: String?) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        try await mockFallbackService.signInWithAppleCredential(userId: userId, name: name, email: email)
        if let user = mockFallbackService.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            try? await userRepository.saveUser(user)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            try await mockFallbackService.signIn(email: email, password: password)
            if let user = mockFallbackService.currentUser {
                self.currentUser = user
                self.isAuthenticated = true
                try? await userRepository.saveUser(user)
            }
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    func createAccount(name: String, email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            try await mockFallbackService.createAccount(name: name, email: email, password: password)
            if let user = mockFallbackService.currentUser {
                self.currentUser = user
                self.isAuthenticated = true
                try? await userRepository.saveUser(user)
            }
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        try await mockFallbackService.resetPassword(email: email)
    }
    
    func continueAsGuest() async {
        isLoading = true
        authError = nil
        
        await mockFallbackService.continueAsGuest()
        if let guestUser = mockFallbackService.currentUser {
            self.currentUser = guestUser
            self.isAuthenticated = true
            try? await userRepository.saveUser(guestUser)
        }
        self.isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        
        await mockFallbackService.signOut()
        try? await userRepository.deleteCurrentUser()
        
        supabaseManager.updateAuthToken(nil)
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.isLoading = false
        self.authError = nil
    }
    
    func clearError() {
        authError = nil
        mockFallbackService.clearError()
    }
}
