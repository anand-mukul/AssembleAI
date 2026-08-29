//
//  TutorResponse.swift
//  AssembleAI
//

import Foundation

// MARK: - Response Priority

/// Priority level governing speech queue interruption and replacement.
enum ResponsePriority: Int, Sendable, Comparable, Codable {
    /// Optional or background encouragement.
    case low = 1
    /// Standard step orientation or confirmation.
    case normal = 2
    /// Proactive corrective guidance.
    case high = 3
    /// Direct user-requested answers or critical safety prompts.
    case immediate = 4
    
    static func < (lhs: ResponsePriority, rhs: ResponsePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Tutor Response Model

/// Spoken tutor utterance with metadata for speech synthesis and telemetry.
struct TutorResponse: Sendable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let priority: ResponsePriority
    let category: String
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        text: String,
        priority: ResponsePriority = .normal,
        category: String = "general",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.priority = priority
        self.category = category
        self.timestamp = timestamp
    }
}

// MARK: - Tutor Response Providing Protocol

/// Protocol for translating behavioral intervention decisions into spoken natural language responses.
protocol TutorResponseProviding: Sendable {
    /// Generates a spoken tutor response for an intervention decision.
    func response(for decision: InterventionDecision) -> TutorResponse?
}

// MARK: - Deterministic Tutor Response Provider

/// Concrete deterministic response provider generating concise, friendly tutor dialogue.
///
/// Serves as the baseline spoken language provider before Apple Foundation Models integration in Phase 8.
struct DeterministicTutorResponseProvider: TutorResponseProviding {
    init() {}
    
    func response(for decision: InterventionDecision) -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        switch decision.action {
        case .remainSilent:
            return nil
            
        case .instruct(let step):
            return TutorResponse(
                text: "Let's start step \(step.stepOrder): \(step.title). \(step.instruction)",
                priority: .normal,
                category: "instruction"
            )
            
        case .confirm(let step):
            let confirmations = [
                "Perfect. That's exactly right.",
                "Great job! Step \(step.stepOrder) is complete.",
                "Nicely done. That component is placed correctly."
            ]
            let chosen = confirmations[step.stepOrder % confirmations.count]
            return TutorResponse(
                text: chosen,
                priority: .normal,
                category: "confirmation"
            )
            
        case .correct(let description, let level):
            let prefix: String
            let priority: ResponsePriority
            switch level {
            case .gentle:
                prefix = "Almost."
                priority = .normal
            case .explicit:
                prefix = "Check your placement."
                priority = .high
            case .detailed:
                prefix = "Let's take a closer look."
                priority = .high
            }
            return TutorResponse(
                text: "\(prefix) \(description)",
                priority: priority,
                category: "correction"
            )
            
        case .requestBetterView(let explanation):
            return TutorResponse(
                text: "I need a clearer view. \(explanation)",
                priority: .normal,
                category: "camera_guidance"
            )
            
        case .offerHelp(let step, _):
            return TutorResponse(
                text: "Need a hand with \(step.title)? I can show you where it goes.",
                priority: .normal,
                category: "stuck_help"
            )
            
        case .respondToUser(let query):
            return TutorResponse(
                text: "Here is what you need to know about \(query).",
                priority: .immediate,
                category: "user_query_response"
            )
        }
    }
}
