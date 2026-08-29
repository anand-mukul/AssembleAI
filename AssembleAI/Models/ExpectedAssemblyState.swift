//
//  ExpectedAssemblyState.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Component requirement for an expected physical assembly state.
nonisolated struct ExpectedComponent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let identifier: String
    let name: String
    let quantity: Int
    
    nonisolated init(id: UUID = UUID(), identifier: String, name: String, quantity: Int = 1) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.quantity = quantity
    }
}

/// Electrical or mechanical connection requirement between two pin points or rails.
nonisolated struct ExpectedConnection: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let from: String
    let to: String
    
    nonisolated init(id: UUID = UUID(), from: String, to: String) {
        self.id = id
        self.from = from
        self.to = to
    }
}

/// Expected physical position or bounding region for a component.
nonisolated struct ExpectedPosition: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let componentID: String
    let targetDescription: String
    let region: CGRect
    
    nonisolated init(id: UUID = UUID(), componentID: String, targetDescription: String, region: CGRect = .zero) {
        self.id = id
        self.componentID = componentID
        self.targetDescription = targetDescription
        self.region = region
    }
}

/// Explicit expected physical state for a specific assembly step.
nonisolated struct ExpectedAssemblyState: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let stepID: UUID
    let stepOrder: Int
    let requiredComponents: [ExpectedComponent]
    let requiredConnections: [ExpectedConnection]
    let requiredPositions: [ExpectedPosition]
    
    nonisolated init(
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

extension ExpectedAssemblyState {
    /// Builds the standard expected physical state specification for a given assembly step.
    nonisolated static func forStep(_ step: AssemblyStep) -> ExpectedAssemblyState {
        switch step.stepOrder {
        case 1:
            return ExpectedAssemblyState(
                stepID: step.id,
                stepOrder: 1,
                requiredComponents: [ExpectedComponent(identifier: "resistor_220", name: "220Ω Resistor")],
                requiredPositions: [ExpectedPosition(componentID: "resistor_220", targetDescription: "Row 10 to Row 15")]
            )
        case 2:
            return ExpectedAssemblyState(
                stepID: step.id,
                stepOrder: 2,
                requiredComponents: [ExpectedComponent(identifier: "capacitor_100uF", name: "100uF Capacitor")],
                requiredPositions: [ExpectedPosition(componentID: "capacitor_100uF", targetDescription: "C2 Header Slot")]
            )
        case 3:
            return ExpectedAssemblyState(
                stepID: step.id,
                stepOrder: 3,
                requiredComponents: [ExpectedComponent(identifier: "led_red", name: "Red LED")],
                requiredConnections: [ExpectedConnection(from: "Anode", to: "Node 12A")]
            )
        case 5:
            return ExpectedAssemblyState(
                stepID: step.id,
                stepOrder: 5,
                requiredComponents: [ExpectedComponent(identifier: "jumper_gnd", name: "GND Jumper Wire")],
                requiredConnections: [ExpectedConnection(from: "GND Rail", to: "Pin Header")]
            )
        default:
            return ExpectedAssemblyState(
                stepID: step.id,
                stepOrder: step.stepOrder,
                requiredComponents: [ExpectedComponent(identifier: "comp_\(step.stepOrder)", name: step.title)]
            )
        }
    }
}

