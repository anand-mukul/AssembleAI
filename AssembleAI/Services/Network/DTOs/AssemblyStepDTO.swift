//
//  AssemblyStepDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.assembly_steps`.
//

import Foundation

/// PostgREST DTO representation of `public.assembly_steps`.
struct AssemblyStepDTO: Codable, Sendable {
    let id: UUID
    let projectId: UUID
    var stepOrder: Int
    var title: String
    var instruction: String
    var expectedState: String
    var expectedDurationMinutes: Int?
    var commonMistakes: [CommonMistake]
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case stepOrder = "step_order"
        case title
        case instruction
        case expectedState = "expected_state"
        case expectedDurationMinutes = "expected_duration_minutes"
        case commonMistakes = "common_mistakes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from domain: AssemblyStep) {
        self.id = domain.id
        self.projectId = domain.projectId
        self.stepOrder = domain.stepOrder
        self.title = domain.title
        self.instruction = domain.instruction
        self.expectedState = domain.expectedState
        self.expectedDurationMinutes = 2
        self.commonMistakes = domain.commonMistakes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    func toDomain() -> AssemblyStep {
        AssemblyStep(
            id: id,
            projectId: projectId,
            stepOrder: stepOrder,
            title: title,
            instruction: instruction,
            expectedState: expectedState,
            commonMistakes: commonMistakes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.projectId = try container.decode(UUID.self, forKey: .projectId)
        self.stepOrder = (try container.decodeIfPresent(Int.self, forKey: .stepOrder)) ?? 1
        self.title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? ""
        self.instruction = (try container.decodeIfPresent(String.self, forKey: .instruction)) ?? ""
        self.expectedState = (try container.decodeIfPresent(String.self, forKey: .expectedState)) ?? "{}"
        self.expectedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .expectedDurationMinutes)
        self.commonMistakes = (try container.decodeIfPresent([CommonMistake].self, forKey: .commonMistakes)) ?? []
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.updatedAt = (try container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
