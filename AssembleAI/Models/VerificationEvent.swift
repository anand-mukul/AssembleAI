//
//  VerificationEvent.swift
//  AssembleAI
//

import Foundation

/// Lightweight research & telemetry record capturing a physical verification event.
nonisolated struct VerificationEvent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let sessionID: UUID
    let stepID: UUID
    let timestamp: Date
    let result: VerificationStatus
    let confidence: Double
    let attemptNumber: Int
    let issueTypes: [StateIssueType]
    
    init(
        id: UUID = UUID(),
        sessionID: UUID,
        stepID: UUID,
        timestamp: Date = Date(),
        result: VerificationStatus,
        confidence: Double,
        attemptNumber: Int,
        issueTypes: [StateIssueType] = []
    ) {
        self.id = id
        self.sessionID = sessionID
        self.stepID = stepID
        self.timestamp = timestamp
        self.result = result
        self.confidence = confidence
        self.attemptNumber = attemptNumber
        self.issueTypes = issueTypes
    }
}
