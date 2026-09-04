//
//  MockCloudSyncBackend.swift
//  AssembleAITests
//

import Foundation
import CloudKit
@testable import AssembleAI

/// In-memory mock cloud backend for unit testing and offline preview environments.
final class MockCloudSyncBackend: CloudSyncBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var remoteSessions: [UUID: AssemblySession] = [:]
    
    init(initialSessions: [AssemblySession] = []) {
        for s in initialSessions {
            remoteSessions[s.id] = s
        }
    }
    
    func uploadSessions(_ sessions: [AssemblySession]) async throws -> [AssemblySession] {
        lock.lock()
        defer { lock.unlock() }
        
        var uploaded: [AssemblySession] = []
        for s in sessions {
            var updated = s
            updated.syncState = .synced
            updated.updatedAt = Date()
            remoteSessions[s.id] = updated
            uploaded.append(updated)
        }
        return uploaded
    }
    
    func fetchRemoteSessions(since: Date?) async throws -> [AssemblySession] {
        lock.lock()
        defer { lock.unlock() }
        
        if let sinceDate = since {
            return remoteSessions.values.filter { $0.updatedAt > sinceDate }
        }
        return Array(remoteSessions.values)
    }
    
    func deleteRemoteSession(id: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }
        remoteSessions.removeValue(forKey: id)
    }
}
