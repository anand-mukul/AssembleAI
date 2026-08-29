//
//  GuidanceGenerationEvent.swift
//  AssembleAI
//

import Foundation

/// Telemetry record capturing Foundation Models generation metadata and fallback events.
struct GuidanceGenerationEvent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let stepID: UUID
    let issueType: StateIssueType
    let generationSucceeded: Bool
    let usedFallback: Bool
    let latencyMilliseconds: Int
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        stepID: UUID,
        issueType: StateIssueType,
        generationSucceeded: Bool,
        usedFallback: Bool,
        latencyMilliseconds: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stepID = stepID
        self.issueType = issueType
        self.generationSucceeded = generationSucceeded
        self.usedFallback = usedFallback
        self.latencyMilliseconds = latencyMilliseconds
    }
}
