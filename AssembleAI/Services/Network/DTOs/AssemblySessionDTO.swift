//
//  AssemblySessionDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.assembly_sessions`.
//

import Foundation

/// PostgREST DTO representation of `public.assembly_sessions`.
struct AssemblySessionDTO: Codable, Sendable {
    let id: UUID
    var userId: UUID?
    let projectId: UUID
    var projectTitle: String?
    var status: String
    var currentStepIndex: Int
    var currentStepOrder: Int
    var completedSteps: [Int]
    var attempts: Int
    var errors: Int
    var syncState: String
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case projectId = "project_id"
        case projectTitle = "project_title"
        case status
        case currentStepIndex = "current_step_index"
        case currentStepOrder = "current_step_order"
        case completedSteps = "completed_steps"
        case attempts
        case errors
        case syncState = "sync_state"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from domain: AssemblySession) {
        self.id = domain.id
        self.userId = domain.userId
        self.projectId = domain.projectId
        self.projectTitle = domain.projectTitle
        self.status = domain.status.rawValue
        self.currentStepIndex = domain.currentStepIndex
        self.currentStepOrder = domain.currentStepOrder
        self.completedSteps = Array(domain.completedSteps).sorted()
        self.attempts = domain.attempts
        self.errors = domain.errors
        self.syncState = domain.syncState.rawValue
        self.startedAt = domain.startedAt
        self.endedAt = domain.endedAt
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    func toDomain() -> AssemblySession {
        AssemblySession(
            id: id,
            userId: userId,
            projectId: projectId,
            projectTitle: projectTitle,
            currentStepIndex: currentStepIndex,
            completedSteps: Set(completedSteps),
            attempts: attempts,
            errors: errors,
            startedAt: startedAt,
            endedAt: endedAt,
            status: SessionStatus(rawValue: status) ?? .inProgress,
            currentStepOrder: currentStepOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: SyncState(rawValue: syncState) ?? .synced
        )
    }
    
    // Custom decoding to safely default missing array/null keys from older schemas
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        self.projectId = try container.decode(UUID.self, forKey: .projectId)
        self.projectTitle = try container.decodeIfPresent(String.self, forKey: .projectTitle)
        self.status = (try container.decodeIfPresent(String.self, forKey: .status)) ?? SessionStatus.inProgress.rawValue
        self.currentStepIndex = (try container.decodeIfPresent(Int.self, forKey: .currentStepIndex)) ?? 0
        self.currentStepOrder = (try container.decodeIfPresent(Int.self, forKey: .currentStepOrder)) ?? 1
        self.completedSteps = (try container.decodeIfPresent([Int].self, forKey: .completedSteps)) ?? []
        self.attempts = (try container.decodeIfPresent(Int.self, forKey: .attempts)) ?? 0
        self.errors = (try container.decodeIfPresent(Int.self, forKey: .errors)) ?? 0
        self.syncState = (try container.decodeIfPresent(String.self, forKey: .syncState)) ?? SyncState.synced.rawValue
        self.startedAt = (try container.decodeIfPresent(Date.self, forKey: .startedAt)) ?? Date()
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.updatedAt = (try container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
