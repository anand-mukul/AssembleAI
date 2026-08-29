//
//  ResearchEvent.swift
//  AssembleAI
//

import Foundation

// MARK: - Research Event Type Taxonomy

/// Controlled event taxonomy for experimental evaluation and CSE thesis research metrics.
public enum ResearchEventType: String, Codable, Hashable, Equatable, Sendable {
    // Session Lifecycle
    case sessionStarted
    case sessionCompleted
    
    // Step Progression Lifecycle
    case stepStarted
    case stepCompleted
    
    // Deterministic Verification Events
    case verificationCorrect
    case verificationIncorrect
    case verificationUncertain
    
    // Behavioral Intervention Events
    case interventionTriggered
    case interventionSuppressed
    
    // Conversational & Speech Events
    case userVoiceStarted
    case userVoiceCompleted
    case assistantResponseGenerated
    case assistantResponseCancelled
    case assistantSpeechStarted
    case assistantSpeechCompleted
    
    // Live Stream Controls
    case liveTutorPaused
    case liveTutorResumed
    case manualAnalysisTriggered
    
    // Legacy Compatibility Events
    case instructionViewed
    case cameraOpened
    case imageCaptured
    case analysisStarted
    case analysisCompleted
    case verificationCompleted
    case guidanceDisplayed
    case retry
}

// MARK: - Research Event Model

/// Anonymized, structured telemetry record capturing interaction timing and experimental metrics.
public struct ResearchEvent: Identifiable, Hashable, Codable, Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let timestamp: Date
    public let sessionID: UUID
    public let projectID: UUID
    public let stepID: UUID?
    public let mode: InteractionMode
    public let eventType: ResearchEventType
    public let durationMilliseconds: Int?
    public let verificationStatus: String?
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        sequence: Int = 0,
        timestamp: Date = Date(),
        sessionID: UUID,
        projectID: UUID,
        stepID: UUID? = nil,
        mode: InteractionMode = .liveTutor,
        eventType: ResearchEventType,
        durationMilliseconds: Int? = nil,
        verificationStatus: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sequence = sequence
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.projectID = projectID
        self.stepID = stepID
        self.mode = mode
        self.eventType = eventType
        self.durationMilliseconds = durationMilliseconds
        self.verificationStatus = verificationStatus
        self.metadata = metadata
    }
    
    /// Formats event record as an RFC 4180-compliant CSV line.
    public var csvLine: String {
        let isoDate = ISO8601DateFormatter().string(from: timestamp)
        let step = stepID?.uuidString ?? ""
        let dur = durationMilliseconds.map { "\($0)" } ?? ""
        let stat = verificationStatus ?? ""
        let metaStr = metadata.isEmpty ? "" : "\"" + metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"") + "\""
        
        return "\(id.uuidString),\(sequence),\(isoDate),\(sessionID.uuidString),\(projectID.uuidString),\(mode.rawValue),\(step),\(eventType.rawValue),\(dur),\(stat),\(metaStr)"
    }
    
    public static var csvHeader: String {
        "event_id,sequence,timestamp,session_id,project_id,mode,step_id,event_type,duration_ms,verification_status,metadata"
    }
}
