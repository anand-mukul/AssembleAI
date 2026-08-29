//
//  AssemblySession.swift
//  AssembleAI
//

import Foundation

/// Lifecycle status for an assembly session.
enum SessionStatus: String, Codable, Hashable, Equatable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case paused = "paused"
}

/// Session tracking metrics for an active or completed physical assembly flow.
struct AssemblySession: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    var userId: UUID?
    let projectId: UUID
    var currentStepIndex: Int
    var completedSteps: Set<Int>
    var attempts: Int
    var errors: Int
    var startedAt: Date
    var endedAt: Date?
    var status: SessionStatus
    var currentStepOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var syncState: SyncState
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        projectId: UUID,
        currentStepIndex: Int = 0,
        completedSteps: Set<Int> = [],
        attempts: Int = 0,
        errors: Int = 0,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: SessionStatus = .inProgress,
        currentStepOrder: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.userId = userId
        self.projectId = projectId
        self.currentStepIndex = currentStepIndex
        self.completedSteps = completedSteps
        self.attempts = attempts
        self.errors = errors
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.currentStepOrder = currentStepOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
    
    /// Convenience initializer for SwiftData persistence mappings
    init(
        id: UUID = UUID(),
        userId: UUID,
        projectId: UUID,
        startedAt: Date,
        completedAt: Date?,
        status: SessionStatus,
        currentStepOrder: Int,
        createdAt: Date,
        updatedAt: Date,
        syncState: SyncState
    ) {
        self.id = id
        self.userId = userId
        self.projectId = projectId
        self.currentStepIndex = max(0, currentStepOrder - 1)
        self.completedSteps = []
        self.attempts = 0
        self.errors = 0
        self.startedAt = startedAt
        self.endedAt = completedAt
        self.status = status
        self.currentStepOrder = currentStepOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
    
    /// Formatted time elapsed string (e.g. "12m 42s")
    var timeElapsedText: String {
        let endDate = endedAt ?? Date()
        let interval = endDate.timeIntervalSince(startedAt)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Formatted duration alias matching summary views
    var durationFormatted: String {
        timeElapsedText
    }
    
    /// Completion timestamp alias for SwiftData persistence mappings
    var completedAt: Date? {
        get { endedAt }
        set { endedAt = newValue }
    }
    
    /// Accuracy percentage metric
    var accuracyPercentage: Int {
        guard attempts > 0 else { return 100 }
        let successful = max(0, attempts - errors)
        return Int((Double(successful) / Double(attempts)) * 100)
    }
}
