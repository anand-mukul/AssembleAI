//
//  AssemblyStep.swift
//  AssembleAI
//

import Foundation

/// Sequential step within an assembly project.
nonisolated struct AssemblyStep: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let projectId: UUID
    var stepOrder: Int
    var title: String
    var instruction: String
    var expectedState: String // Stored as JSON string representation
    let createdAt: Date
    var updatedAt: Date
    
    var visualContract: VisualContract? {
        guard let data = expectedState.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VisualContract.self, from: data)
    }
    
    nonisolated init(
        id: UUID = UUID(),
        projectId: UUID,
        stepOrder: Int,
        title: String,
        instruction: String,
        expectedState: String = "{}",
        visualContract: VisualContract? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.stepOrder = stepOrder
        self.title = title
        self.instruction = instruction
        if let contract = visualContract,
           let data = try? JSONEncoder().encode(contract),
           let str = String(data: data, encoding: .utf8) {
            self.expectedState = str
        } else {
            self.expectedState = expectedState
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
