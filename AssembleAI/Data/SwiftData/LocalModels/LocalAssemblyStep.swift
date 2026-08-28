//
//  LocalAssemblyStep.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalAssemblyStep {
    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var stepOrder: Int
    var title: String
    var instruction: String
    var expectedState: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        stepOrder: Int,
        title: String,
        instruction: String,
        expectedState: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.stepOrder = stepOrder
        self.title = title
        self.instruction = instruction
        self.expectedState = expectedState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDomainModel() -> AssemblyStep {
        AssemblyStep(
            id: id,
            projectId: projectId,
            stepOrder: stepOrder,
            title: title,
            instruction: instruction,
            expectedState: expectedState,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func fromDomainModel(_ step: AssemblyStep) -> LocalAssemblyStep {
        LocalAssemblyStep(
            id: step.id,
            projectId: step.projectId,
            stepOrder: step.stepOrder,
            title: step.title,
            instruction: step.instruction,
            expectedState: step.expectedState,
            createdAt: step.createdAt,
            updatedAt: step.updatedAt
        )
    }
}
