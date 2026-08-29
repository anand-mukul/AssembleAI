//
//  ObservedAssemblyState.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Component detected during visual state estimation.
struct ObservedComponent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let identifier: String?
    let name: String
    let confidence: Double
    let boundingBox: CGRect
    
    init(id: UUID = UUID(), identifier: String? = nil, name: String, confidence: Double, boundingBox: CGRect = .zero) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
    
    var isUncertain: Bool {
        confidence < 0.50 || identifier == nil
    }
}

/// Connection relationship detected during visual state estimation.
struct ObservedConnection: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let from: String
    let to: String
    let confidence: Double
    
    init(id: UUID = UUID(), from: String, to: String, confidence: Double) {
        self.id = id
        self.from = from
        self.to = to
        self.confidence = confidence
    }
}

/// Component position detected during visual state estimation.
struct ObservedPosition: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let componentID: String
    let detectedDescription: String
    let region: CGRect
    let confidence: Double
    
    init(id: UUID = UUID(), componentID: String, detectedDescription: String, region: CGRect = .zero, confidence: Double) {
        self.id = id
        self.componentID = componentID
        self.detectedDescription = detectedDescription
        self.region = region
        self.confidence = confidence
    }
}

/// Higher-level observed physical state converted from `VisualObservation`.
struct ObservedAssemblyState: Identifiable, Sendable {
    let id: UUID
    let detectedComponents: [ObservedComponent]
    let detectedConnections: [ObservedConnection]
    let detectedPositions: [ObservedPosition]
    let overallConfidence: Double
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        detectedComponents: [ObservedComponent] = [],
        detectedConnections: [ObservedConnection] = [],
        detectedPositions: [ObservedPosition] = [],
        overallConfidence: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.detectedComponents = detectedComponents
        self.detectedConnections = detectedConnections
        self.detectedPositions = detectedPositions
        self.overallConfidence = overallConfidence
        self.timestamp = timestamp
    }
}
