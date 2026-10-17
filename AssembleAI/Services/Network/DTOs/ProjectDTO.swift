//
//  ProjectDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.projects`.
//

import Foundation

/// PostgREST DTO representation of `public.projects`.
nonisolated struct ProjectDTO: Codable, Sendable {
    let id: UUID
    var ownerId: UUID?
    var title: String
    var description: String
    var difficulty: String
    var estimatedMinutes: Int
    var thumbnailPath: String?
    var category: String?
    var isPublic: Bool?
    var syncState: String
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case difficulty
        case estimatedMinutes = "estimated_minutes"
        case thumbnailPath = "thumbnail_path"
        case category
        case isPublic = "is_public"
        case syncState = "sync_state"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    nonisolated init(from domain: Project) {
        self.id = domain.id
        self.ownerId = domain.ownerId
        self.title = domain.title
        self.description = domain.description
        self.difficulty = domain.difficulty
        self.estimatedMinutes = domain.estimatedMinutes
        self.thumbnailPath = domain.thumbnailPath
        self.category = domain.category
        self.isPublic = true
        self.syncState = domain.syncState.rawValue
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    nonisolated func toDomain() -> Project {
        Project(
            id: id,
            ownerId: ownerId,
            title: title,
            description: description,
            difficulty: difficulty,
            estimatedMinutes: estimatedMinutes,
            thumbnailPath: thumbnailPath,
            category: category ?? "General Assembly",
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: SyncState(rawValue: syncState) ?? .synced
        )
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        self.title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled Assembly"
        self.description = (try container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.difficulty = (try container.decodeIfPresent(String.self, forKey: .difficulty)) ?? "Beginner"
        self.estimatedMinutes = (try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)) ?? 30
        self.thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic)
        self.syncState = (try container.decodeIfPresent(String.self, forKey: .syncState)) ?? SyncState.synced.rawValue
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.updatedAt = (try container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
