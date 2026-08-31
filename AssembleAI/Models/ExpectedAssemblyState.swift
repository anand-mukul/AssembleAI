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
    /// Builds the expected physical state specification from a step's visual contract.
    ///
    /// In production, this reads structured data from the step's `VisualContract`.
    /// For legacy steps without contracts, it falls back to a generic component expectation.
    nonisolated static func forStep(_ step: AssemblyStep) -> ExpectedAssemblyState {
        // Attempt to decode visual contract from step's expectedState JSON
        if let contractData = step.expectedState.data(using: .utf8),
           let contract = try? JSONDecoder().decode(VisualContract.self, from: contractData),
           !contract.requiredComponentIds.isEmpty {
            return fromVisualContract(contract, step: step)
        }
        
        // Fallback: generic component expectation from step metadata
        return ExpectedAssemblyState(
            stepID: step.id,
            stepOrder: step.stepOrder,
            requiredComponents: [ExpectedComponent(identifier: "comp_\(step.stepOrder)", name: step.title)]
        )
    }
    
    /// Builds expected state from a typed `ProjectStepSummary` visual contract.
    nonisolated static func forStepSummary(_ summary: ProjectStepSummary, projectId: UUID) -> ExpectedAssemblyState {
        guard let contract = summary.visualContract else {
            return ExpectedAssemblyState(
                stepID: summary.id,
                stepOrder: summary.stepOrder,
                requiredComponents: [ExpectedComponent(identifier: "comp_\(summary.stepOrder)", name: summary.title)]
            )
        }
        
        return fromVisualContract(contract, stepID: summary.id, stepOrder: summary.stepOrder)
    }
    
    /// Converts a `VisualContract` into an `ExpectedAssemblyState`.
    private nonisolated static func fromVisualContract(
        _ contract: VisualContract,
        step: AssemblyStep? = nil,
        stepID: UUID? = nil,
        stepOrder: Int? = nil
    ) -> ExpectedAssemblyState {
        let resolvedStepID = stepID ?? step?.id ?? UUID()
        let resolvedStepOrder = stepOrder ?? step?.stepOrder ?? 0
        
        // Map required component IDs to ExpectedComponent
        let components = contract.requiredComponentIds.map { partId in
            ExpectedComponent(identifier: partId, name: partId)
        }
        
        // Map pin placements and expected connections to ExpectedConnection
        var connections: [ExpectedConnection] = []
        for placement in contract.pinPlacements {
            connections.append(ExpectedConnection(
                from: placement.fromPin.label,
                to: placement.toPin.label
            ))
        }
        for conn in contract.expectedConnections {
            connections.append(ExpectedConnection(
                from: conn.fromNode,
                to: conn.toNode
            ))
        }
        
        // Map pin placements to ExpectedPosition
        let positions = contract.pinPlacements.map { placement in
            ExpectedPosition(
                componentID: placement.partId,
                targetDescription: "\(placement.fromPin.label) to \(placement.toPin.label)"
            )
        }
        
        // Map spatial placements to ExpectedPosition (physical domain)
        let spatialPositions = contract.spatialPlacements.map { placement in
            ExpectedPosition(
                componentID: placement.partId,
                targetDescription: placement.locationDescription,
                region: placement.targetRegion ?? .zero
            )
        }
        
        return ExpectedAssemblyState(
            stepID: resolvedStepID,
            stepOrder: resolvedStepOrder,
            requiredComponents: components,
            requiredConnections: connections,
            requiredPositions: positions + spatialPositions
        )
    }
}


