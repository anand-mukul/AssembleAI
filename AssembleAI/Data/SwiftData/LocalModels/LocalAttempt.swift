//
//  LocalAttempt.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalAttempt {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var stepId: UUID
    var attemptNumber: Int
    var statusRaw: String
    var confidence: Double?
    var detectedState: String?
    var explanation: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        stepId: UUID,
        attemptNumber: Int,
        statusRaw: String,
        confidence: Double? = nil,
        detectedState: String? = nil,
        explanation: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.stepId = stepId
        self.attemptNumber = attemptNumber
        self.statusRaw = statusRaw
        self.confidence = confidence
        self.detectedState = detectedState
        self.explanation = explanation
        self.createdAt = createdAt
    }
    
    func toDomainModel() -> Attempt {
        Attempt(
            id: id,
            sessionId: sessionId,
            stepId: stepId,
            attemptNumber: attemptNumber,
            status: AttemptStatus(rawValue: statusRaw) ?? .uncertain,
            confidence: confidence,
            detectedState: detectedState,
            explanation: explanation,
            createdAt: createdAt
        )
    }
    
    static func fromDomainModel(_ attempt: Attempt) -> LocalAttempt {
        LocalAttempt(
            id: attempt.id,
            sessionId: attempt.sessionId,
            stepId: attempt.stepId,
            attemptNumber: attempt.attemptNumber,
            statusRaw: attempt.status.rawValue,
            confidence: attempt.confidence,
            detectedState: attempt.detectedState,
            explanation: attempt.explanation,
            createdAt: attempt.createdAt
        )
    }
}
