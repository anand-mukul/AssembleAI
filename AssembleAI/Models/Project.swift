//
//  Project.swift
//  AssembleAI
//

import Foundation

/// Synchronization state for local-first records.
nonisolated enum SyncState: String, Codable, Hashable, Equatable, Sendable {
    case synced
    case pendingUpload
    case pendingDelete
    case conflict
}

/// Project Domain Model representing an electronics or physical task assembly workflow.
nonisolated struct Project: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    var title: String
    var description: String
    var difficulty: String
    var estimatedMinutes: Int
    var thumbnailPath: String?
    let createdAt: Date
    var updatedAt: Date
    var syncState: SyncState
    
    nonisolated init(
        id: UUID = UUID(),
        ownerId: UUID,
        title: String,
        description: String = "",
        difficulty: String = "Beginner",
        estimatedMinutes: Int = 30,
        thumbnailPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .pendingUpload
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}
