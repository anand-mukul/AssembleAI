//
//  LocalAssemblySession.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalAssemblySession {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var projectId: UUID
    var startedAt: Date
    var completedAt: Date?
    var statusRaw: String
    var currentStepOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStateRaw: String
    
    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        projectId: UUID,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        statusRaw: String = SessionStatus.notStarted.rawValue,
        currentStepOrder: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStateRaw: String = SyncState.pendingUpload.rawValue
    ) {
        self.id = id
        self.userId = userId
        self.projectId = projectId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.statusRaw = statusRaw
        self.currentStepOrder = currentStepOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStateRaw = syncStateRaw
    }
    
    func toDomainModel() -> AssemblySession {
        AssemblySession(
            id: id,
            userId: userId,
            projectId: projectId,
            startedAt: startedAt,
            completedAt: completedAt,
            status: SessionStatus(rawValue: statusRaw) ?? .notStarted,
            currentStepOrder: currentStepOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: SyncState(rawValue: syncStateRaw) ?? .pendingUpload
        )
    }
    
    static func fromDomainModel(_ session: AssemblySession) -> LocalAssemblySession {
        LocalAssemblySession(
            id: session.id,
            userId: session.userId,
            projectId: session.projectId,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            statusRaw: session.status.rawValue,
            currentStepOrder: session.currentStepOrder,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            syncStateRaw: session.syncState.rawValue
        )
    }
}
