//
//  LocalProject.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalProject {
    @Attribute(.unique) var id: UUID
    var ownerId: UUID
    var title: String
    var projectDescription: String
    var difficulty: String
    var estimatedMinutes: Int
    var thumbnailPath: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStateRaw: String
    
    init(
        id: UUID = UUID(),
        ownerId: UUID,
        title: String,
        projectDescription: String = "",
        difficulty: String = "Beginner",
        estimatedMinutes: Int = 30,
        thumbnailPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStateRaw: String = SyncState.pendingUpload.rawValue
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.projectDescription = projectDescription
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStateRaw = syncStateRaw
    }
    
    func toDomainModel() -> Project {
        Project(
            id: id,
            ownerId: ownerId,
            title: title,
            description: projectDescription,
            difficulty: difficulty,
            estimatedMinutes: estimatedMinutes,
            thumbnailPath: thumbnailPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: SyncState(rawValue: syncStateRaw) ?? .pendingUpload
        )
    }
    
    static func fromDomainModel(_ project: Project) -> LocalProject {
        LocalProject(
            id: project.id,
            ownerId: project.ownerId,
            title: project.title,
            projectDescription: project.description,
            difficulty: project.difficulty,
            estimatedMinutes: project.estimatedMinutes,
            thumbnailPath: project.thumbnailPath,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            syncStateRaw: project.syncState.rawValue
        )
    }
}
