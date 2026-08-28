//
//  AssemblySession.swift
//  AssembleAI
//

import Foundation

enum SessionStatus: String, Codable, Equatable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case paused = "paused"
    case completed = "completed"
    case abandoned = "abandoned"
}

/// Assembly Execution Session domain model.
struct AssemblySession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let projectId: UUID
    let startedAt: Date
    var completedAt: Date?
    var status: SessionStatus
    var currentStepOrder: Int
    let createdAt: Date
    var updatedAt: Date
    var syncState: SyncState
    
    nonisolated init(
        id: UUID = UUID(),
        userId: UUID,
        projectId: UUID,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: SessionStatus = .notStarted,
        currentStepOrder: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .pendingUpload
    ) {
        self.id = id
        self.userId = userId
        self.projectId = projectId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.currentStepOrder = currentStepOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}
