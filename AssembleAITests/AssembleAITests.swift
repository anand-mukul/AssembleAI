//
//  AssembleAITests.swift
//  AssembleAITests
//

import Testing
import Foundation
import CloudKit
@testable import AssembleAI

struct AssembleAITests {

    @Test func testCloudKitAuthServiceGuestFlow() async throws {
        let authService = await CloudKitAuthService()
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
}
