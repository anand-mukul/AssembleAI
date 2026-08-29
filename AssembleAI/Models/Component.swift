//
//  Component.swift
//  AssembleAI
//

import Foundation

/// Physical component used in an assembly project.
nonisolated struct Component: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    let projectId: UUID
    var name: String
    var type: String
    var description: String
    var metadata: String // JSON string
    let createdAt: Date
    var updatedAt: Date
    
    nonisolated init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        type: String = "hardware",
        description: String = "",
        metadata: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.type = type
        self.description = description
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
