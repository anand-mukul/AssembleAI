//
//  LocalFirstSessionRepositoryTests.swift
//  AssembleAITests
//

import XCTest
import SwiftData
@testable import AssembleAI

@MainActor
final class LocalFirstSessionRepositoryTests: XCTestCase {
    
    private var container: ModelContainer!
    private var repository: LocalFirstSessionRepository!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([LocalAssemblySession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        repository = LocalFirstSessionRepository(modelContext: container.mainContext)
    }
    
    override func tearDown() {
        container = nil
        repository = nil
        super.tearDown()
    }
    
    func testSaveAndFetchSession() async throws {
        let sessionId = UUID()
        let userId = UUID()
        let projId = UUID()
        
        let session = AssemblySession(
            id: sessionId,
            userId: userId,
            projectId: projId,
            status: .inProgress,
            currentStepOrder: 1
        )
        
        try await repository.saveSession(session)
        
        let fetched = try await repository.fetchSession(id: sessionId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, sessionId)
        XCTAssertEqual(fetched?.status, .inProgress)
        
        let userSessions = try await repository.fetchSessions(userId: userId)
        XCTAssertEqual(userSessions.count, 1)
    }
    
    func testUpdateExistingSession() async throws {
        let sessionId = UUID()
        let projId = UUID()
        
        var session = AssemblySession(
            id: sessionId,
            projectId: projId,
            status: .inProgress,
            currentStepOrder: 1
        )
        
        try await repository.saveSession(session)
        
        // Update to completed
        session.status = .completed
        session.currentStepOrder = 5
        session.completedAt = Date()
        
        try await repository.saveSession(session)
        
        let updated = try await repository.fetchSession(id: sessionId)
        XCTAssertEqual(updated?.status, .completed)
        XCTAssertEqual(updated?.currentStepOrder, 5)
        XCTAssertNotNil(updated?.completedAt)
    }
}
