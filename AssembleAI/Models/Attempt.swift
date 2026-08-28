//
//  Attempt.swift
//  AssembleAI
//

import Foundation

enum AttemptStatus: String, Codable, Equatable {
    case correct
    case incorrect
    case uncertain
}

/// Verification attempt record for an assembly step.
struct Attempt: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionId: UUID
    let stepId: UUID
    let attemptNumber: Int
    var status: AttemptStatus
    var confidence: Double?
    var detectedState: String? // JSON string
    var explanation: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        stepId: UUID,
        attemptNumber: Int,
        status: AttemptStatus,
        confidence: Double? = nil,
        detectedState: String? = nil,
        explanation: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.stepId = stepId
        self.attemptNumber = attemptNumber
        self.status = status
        self.confidence = confidence
        self.detectedState = detectedState
        self.explanation = explanation
        self.createdAt = createdAt
    }
}
