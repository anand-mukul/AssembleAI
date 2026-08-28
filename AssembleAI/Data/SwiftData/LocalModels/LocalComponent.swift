//
//  LocalComponent.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalComponent {
    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var name: String
    var type: String
    var componentDescription: String
    var metadata: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        type: String = "hardware",
        componentDescription: String = "",
        metadata: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.type = type
        self.componentDescription = componentDescription
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDomainModel() -> Component {
        Component(
            id: id,
            projectId: projectId,
            name: name,
            type: type,
            description: componentDescription,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func fromDomainModel(_ component: Component) -> LocalComponent {
        LocalComponent(
            id: component.id,
            projectId: component.projectId,
            name: component.name,
            type: component.type,
            componentDescription: component.description,
            metadata: component.metadata,
            createdAt: component.createdAt,
            updatedAt: component.updatedAt
        )
    }
}
