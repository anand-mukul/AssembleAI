//
//  ComponentDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.components`.
//

import Foundation

/// PostgREST DTO representation of `public.components`.
nonisolated struct ComponentDTO: Codable, Sendable {
    let id: UUID
    let projectId: UUID
    var name: String
    var type: String
    var description: String
    var metadata: String
    var partId: String?
    var isRequired: Bool?
    var quantity: Int?
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case name
        case type
        case description
        case metadata
        case partId = "part_id"
        case isRequired = "is_required"
        case quantity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    nonisolated init(from domain: Component) {
        self.id = domain.id
        self.projectId = domain.projectId
        self.name = domain.name
        self.type = domain.type
        self.description = domain.description
        self.metadata = domain.metadata
        self.partId = "part_\(domain.name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        self.isRequired = true
        self.quantity = 1
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    nonisolated func toDomain() -> Component {
        Component(
            id: id,
            projectId: projectId,
            name: name,
            type: type,
            description: description,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.projectId = try container.decode(UUID.self, forKey: .projectId)
        self.name = (try container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.type = (try container.decodeIfPresent(String.self, forKey: .type)) ?? "hardware"
        self.description = (try container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.metadata = (try container.decodeIfPresent(String.self, forKey: .metadata)) ?? "{}"
        self.partId = try container.decodeIfPresent(String.self, forKey: .partId)
        self.isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired)
        self.quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
