//
//  AssemblyStep.swift
//  AssembleAI
//

import Foundation

/// Sequential step within an assembly project.
nonisolated struct AssemblyStep: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let projectId: UUID
    var stepOrder: Int
    var title: String
    var instruction: String
    var expectedState: String // Stored as JSON string representation
    let createdAt: Date
    var updatedAt: Date
    
    nonisolated init(
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
}
