//
//  AttemptDTO.swift
//  AssembleAI
//

import Foundation

/// PostgREST Data Transfer Object for `public.attempts` table.
public struct AttemptDTO: Codable, Sendable {
    public let id: String
    public let session_id: String
    public let step_id: String
    public let attempt_number: Int
    public let status: String
    public let confidence: Double?
    public let detected_state: String?
    public let explanation: String?
    public let created_at: String

    public init(
        id: String,
        sessionId: String,
        stepId: String,
        attemptNumber: Int,
        status: String,
        confidence: Double? = nil,
        detectedState: String? = nil,
        explanation: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.session_id = sessionId
        self.step_id = stepId
        self.attempt_number = attemptNumber
        self.status = status
        self.confidence = confidence
        self.detected_state = detectedState
        self.explanation = explanation
        self.created_at = createdAt
    }

    init(domain: Attempt) {
        self.id = domain.id.uuidString.lowercased()
        self.session_id = domain.sessionId.uuidString.lowercased()
        self.step_id = domain.stepId.uuidString.lowercased()
        self.attempt_number = domain.attemptNumber
        self.status = domain.status.rawValue
        self.confidence = domain.confidence
        self.detected_state = domain.detectedState
        self.explanation = domain.explanation
        self.created_at = ISO8601DateFormatter().string(from: domain.createdAt)
    }

    func toDomain() -> Attempt {
        let formatter = ISO8601DateFormatter()
        let createdDate = formatter.date(from: created_at) ?? Date()
        let parsedStatus = AttemptStatus(rawValue: status) ?? .uncertain

        return Attempt(
            id: UUID(uuidString: id) ?? UUID(),
            sessionId: UUID(uuidString: session_id) ?? UUID(),
            stepId: UUID(uuidString: step_id) ?? UUID(),
            attemptNumber: attempt_number,
            status: parsedStatus,
            confidence: confidence,
            detectedState: detected_state,
            explanation: explanation,
            createdAt: createdDate
        )
    }
}
