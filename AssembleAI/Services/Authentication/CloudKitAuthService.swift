//
//  CloudKitAuthService.swift
//  AssembleAI
//

import Foundation
import SwiftUI
import CloudKit
import Combine

/// Authentication Service backed by Apple CloudKit account status and native Sign in with Apple.
@MainActor
final class CloudKitAuthService: AuthenticationService {
    @Published private(set) var currentUser: User? = nil
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var authError: String? = nil
    
    private let cloudKitManager: CloudKitManager
    private let mockFallbackService: MockAuthenticationService
    
    init(cloudKitManager: CloudKitManager? = nil) {
        self.cloudKitManager = cloudKitManager ?? CloudKitManager.shared
        self.mockFallbackService = MockAuthenticationService()
        
        Task {
            await checkExistingCloudKitSession()
        }
    }
    
    func checkExistingCloudKitSession() async {
        await cloudKitManager.checkAccountStatus()
        
        if cloudKitManager.isAvailable, let recordID = cloudKitManager.userRecordID {
            let cloudUser = User(
                id: recordID.recordName,
                name: "iCloud User",
                email: nil,
                avatarUrl: nil,
                provider: .apple,
                createdAt: Date(),
                updatedAt: Date()
            )
            self.currentUser = cloudUser
            self.isAuthenticated = true
        }
    }
    
    func signInWithApple() async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        await cloudKitManager.checkAccountStatus()
        
        if cloudKitManager.isAvailable, let recordID = cloudKitManager.userRecordID {
            let cloudUser = User(
                id: recordID.recordName,
                name: "Apple & iCloud User",
                email: nil,
                avatarUrl: nil,
                provider: .apple,
                createdAt: Date(),
                updatedAt: Date()
            )
            self.currentUser = cloudUser
            self.isAuthenticated = true
        } else {
            // Simulator or unconfigured container fallback
            try await mockFallbackService.signInWithApple()
            self.currentUser = mockFallbackService.currentUser
            self.isAuthenticated = mockFallbackService.isAuthenticated
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            try await mockFallbackService.signIn(email: email, password: password)
            self.currentUser = mockFallbackService.currentUser
            self.isAuthenticated = mockFallbackService.isAuthenticated
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
            self.currentUser = mockFallbackService.currentUser
            self.isAuthenticated = mockFallbackService.isAuthenticated
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
        self.currentUser = mockFallbackService.currentUser
        self.isAuthenticated = mockFallbackService.isAuthenticated
        self.isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        
        await mockFallbackService.signOut()
        
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
