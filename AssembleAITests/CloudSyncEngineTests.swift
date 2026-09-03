//
//  CloudSyncEngineTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class CloudSyncEngineTests: XCTestCase {
    
    func testUploadPendingSessions() async {
        let backend = MockCloudSyncBackend()
        let engine = CloudSyncEngine(backend: backend)
        
        let local = [
            AssemblySession(
                projectId: UUID(),
                currentStepIndex: 1,
                status: .inProgress,
                syncState: .pendingUpload
            )
        ]
        
        let (synced, event) = await engine.synchronizeSessions(localSessions: local)
        
        XCTAssertEqual(synced.count, 1)
        XCTAssertEqual(synced[0].syncState, .synced)
        
        switch event {
        case .syncCompleted(let uploaded, _):
            XCTAssertEqual(uploaded, 1)
        default:
            XCTFail("Expected .syncCompleted, got \(event)")
        }
    }
    
    func testDownloadNewRemoteSessions() async {
        let remoteSession = AssemblySession(
            projectId: UUID(),
            currentStepIndex: 2,
            status: .inProgress,
            syncState: .synced
        )
        let backend = MockCloudSyncBackend(initialSessions: [remoteSession])
        let engine = CloudSyncEngine(backend: backend)
        
        // Empty local list
        let (synced, event) = await engine.synchronizeSessions(localSessions: [])
        
        XCTAssertEqual(synced.count, 1)
        XCTAssertEqual(synced[0].id, remoteSession.id)
        
        switch event {
        case .syncCompleted(_, let downloaded):
            XCTAssertEqual(downloaded, 1)
        default:
            XCTFail("Expected .syncCompleted, got \(event)")
        }
    }
    
    func testConflictResolutionUnionSteps() {
        let backend = MockCloudSyncBackend()
        let engine = CloudSyncEngine(backend: backend)
        
        let id = UUID()
        let projId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)
        
        let local = AssemblySession(
            id: id,
            projectId: projId,
            currentStepIndex: 1,
            completedSteps: [1, 2],
            attempts: 3,
            errors: 1,
            status: .inProgress,
            updatedAt: olderDate,
            syncState: .pendingUpload
        )
        
        let remote = AssemblySession(
            id: id,
            projectId: projId,
            currentStepIndex: 2,
            completedSteps: [2, 3],
            attempts: 5,
            errors: 2,
            status: .completed,
            updatedAt: newerDate,
            syncState: .synced
        )
        
        let resolved = engine.resolveConflict(local: local, remote: remote)
        
        // Completed steps should be union [1, 2, 3]
        XCTAssertEqual(resolved.completedSteps, [1, 2, 3])
        // Status should be LWW (.completed from newer remote)
        XCTAssertEqual(resolved.status, .completed)
        // Step index should be max (2)
        XCTAssertEqual(resolved.currentStepIndex, 2)
        // Sync state should be .synced
        XCTAssertEqual(resolved.syncState, .synced)
    }
}
