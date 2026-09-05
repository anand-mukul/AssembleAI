//
//  AssembleAITests.swift
//  AssembleAITests
//

import Testing
import Foundation
@testable import AssembleAI

struct AssembleAITests {

    @Test func testSupabaseAuthServiceGuestFlow() async throws {
        let authService = await SupabaseAuthService()
        await authService.continueAsGuest()
        
        let isAuth = await authService.isAuthenticated
        let user = await authService.currentUser
        
        #expect(isAuth == true)
        #expect(user?.isGuest == true)
        #expect(user?.provider == .guest)
    }

    @Test func testProjectDomainModelCreation() throws {
        let id = UUID()
        let ownerId = UUID()
        let now = Date()
        
        let project = Project(
            id: id,
            ownerId: ownerId,
            title: "Solder PCB Component",
            description: "Step-by-step surface mount component assembly",
            difficulty: "Intermediate",
            estimatedMinutes: 45,
            thumbnailPath: nil,
            createdAt: now,
            updatedAt: now,
            syncState: .pendingUpload
        )
        
        #expect(project.id == id)
        #expect(project.ownerId == ownerId)
        #expect(project.title == "Solder PCB Component")
        #expect(project.estimatedMinutes == 45)
        #expect(project.syncState == .pendingUpload)
    }

    @Test func testSupabaseAuthServiceDeleteAccountFlow() async throws {
        let authService = await SupabaseAuthService()
        await authService.continueAsGuest()
        #expect(await authService.isAuthenticated == true)
        
        try await authService.deleteAccount()
        #expect(await authService.isAuthenticated == false)
        #expect(await authService.currentUser == nil)
    }

    @Test func testSupabaseAuthServiceSignOutFlow() async throws {
        let authService = await SupabaseAuthService()
        await authService.continueAsGuest()
        #expect(await authService.isAuthenticated == true)
        
        try await authService.signOut()
        #expect(await authService.isAuthenticated == false)
        #expect(await authService.currentUser == nil)
    }

    @Test func testAuthErrorDescriptions() {
        let invalid = AuthError.invalidCredentials
        #expect(invalid.errorDescription == "Invalid email or password. Please verify your credentials.")
        
        let cancelled = AuthError.userCancelled
        #expect(cancelled.errorDescription == "Authentication was cancelled.")
        
        let appleFailed = AuthError.appleSignInFailed("Token mismatch")
        #expect(appleFailed.errorDescription?.contains("Token mismatch") == true)
        
        let offline = AuthError.networkUnavailable
        #expect(offline.errorDescription?.contains("internet connection") == true)
    }

    @Test func testAppErrorTaxonomyDescriptions() {
        let authErr = AppError.authentication("Auth failed")
        #expect(authErr.errorDescription == "Auth failed")
        
        let dbErr = AppError.database("SQL fault")
        #expect(dbErr.errorDescription == "We couldn't sync your project data. Please try again.")
        
        let netErr = AppError.network("Timeout")
        #expect(netErr.errorDescription == "Unable to connect to server. Please check your network connection.")
    }
    
    @Test func testAppConfigPlaceholderSafety() {
        // AppConfig placeholder strings must never be considered configured
        #expect(AppConfig.supabaseUrl.contains("https://") || AppConfig.supabaseUrl == "SUPABASE_URL_NOT_FOUND")
        if AppConfig.supabaseUrl == "SUPABASE_URL_NOT_FOUND" {
            #expect(AppConfig.isSupabaseConfigured == false)
        }
    }
}
