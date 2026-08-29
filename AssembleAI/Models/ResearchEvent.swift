//
//  ResearchEvent.swift
//  AssembleAI
//

import Foundation

/// Event lifecycle type for research evaluation telemetry.
enum ResearchEventType: String, Codable, Hashable, Equatable, Sendable {
    case sessionStarted
    case instructionViewed
    case cameraOpened
    case imageCaptured
    case analysisStarted
    case analysisCompleted
    case verificationCompleted
    case guidanceDisplayed
    case retry
    case stepCompleted
    case sessionCompleted
}

/// Anonymized pseudonymous telemetry record for research metric calculation.
nonisolated struct ResearchEvent: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let sessionID: UUID
    let projectID: UUID
    let stepID: UUID
    let eventType: ResearchEventType
    let durationMilliseconds: Int?
    let attemptNumber: Int?
    let verificationStatus: String?
    
    nonisolated init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: UUID,
        projectID: UUID,
        stepID: UUID,
        eventType: ResearchEventType,
        durationMilliseconds: Int? = nil,
        attemptNumber: Int? = nil,
        verificationStatus: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.projectID = projectID
        self.stepID = stepID
        self.eventType = eventType
        self.durationMilliseconds = durationMilliseconds
        self.attemptNumber = attemptNumber
        self.verificationStatus = verificationStatus
    }
    
    /// Formats event record as a CSV line.
    nonisolated var csvLine: String {
        let ISO8601Date = ISO8601DateFormatter().string(from: timestamp)
        let dur = durationMilliseconds.map { "\($0)" } ?? ""
        let att = attemptNumber.map { "\($0)" } ?? ""
        let stat = verificationStatus ?? ""
        
        return "\(id.uuidString),\(ISO8601Date),\(sessionID.uuidString),\(projectID.uuidString),\(stepID.uuidString),\(eventType.rawValue),\(dur),\(att),\(stat)"
    }
    
    nonisolated static var csvHeader: String {
        "event_id,timestamp,session_id,project_id,step_id,event_type,duration_ms,attempt_number,verification_status"
    }
}
