//
//  ExpectedAssemblyState.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Component requirement for an expected physical assembly state.
struct ExpectedComponent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let identifier: String
    let name: String
    let quantity: Int
    
    init(id: UUID = UUID(), identifier: String, name: String, quantity: Int = 1) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.quantity = quantity
    }
}

/// Electrical or mechanical connection requirement between two pin points or rails.
struct ExpectedConnection: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let from: String
    let to: String
    
    init(id: UUID = UUID(), from: String, to: String) {
        self.id = id
        self.from = from
        self.to = to
    }
}

/// Expected physical position or bounding region for a component.
struct ExpectedPosition: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let componentID: String
    let targetDescription: String
    let region: CGRect
    
    init(id: UUID = UUID(), componentID: String, targetDescription: String, region: CGRect = .zero) {
        self.id = id
        self.componentID = componentID
        self.targetDescription = targetDescription
        self.region = region
    }
}

/// Explicit expected physical state for a specific assembly step.
struct ExpectedAssemblyState: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let stepID: UUID
    let stepOrder: Int
    let requiredComponents: [ExpectedComponent]
    let requiredConnections: [ExpectedConnection]
    let requiredPositions: [ExpectedPosition]
    
    init(
        id: UUID = UUID(),
        stepID: UUID,
        stepOrder: Int,
        requiredComponents: [ExpectedComponent] = [],
        requiredConnections: [ExpectedConnection] = [],
        requiredPositions: [ExpectedPosition] = []
    ) {
        self.id = id
        self.stepID = stepID
        self.stepOrder = stepOrder
        self.requiredComponents = requiredComponents
        self.requiredConnections = requiredConnections
        self.requiredPositions = requiredPositions
    }
}
