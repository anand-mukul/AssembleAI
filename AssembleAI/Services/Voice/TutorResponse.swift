//
//  TutorResponse.swift
//  AssembleAI
//

import Foundation

// MARK: - Response Priority

/// Priority level governing speech queue interruption and replacement.
nonisolated enum ResponsePriority: Int, Sendable, Comparable, Codable {
    /// Optional or background encouragement.
    case low = 1
    /// Standard step orientation or confirmation.
    case normal = 2
    /// Proactive corrective guidance.
    case high = 3
    /// Direct user-requested answers or critical safety prompts.
    case immediate = 4
    
    nonisolated static func < (lhs: ResponsePriority, rhs: ResponsePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Tutor Response Model

/// Spoken tutor utterance with metadata for speech synthesis and telemetry.
nonisolated struct TutorResponse: Sendable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let priority: ResponsePriority
    let category: String
    let timestamp: Date
    
    nonisolated init(
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
nonisolated protocol TutorResponseProviding: Sendable {
    /// Generates a spoken tutor response for an intervention decision.
    nonisolated func response(for decision: InterventionDecision) -> TutorResponse?
}

// MARK: - Deterministic Tutor Response Provider

/// Concrete deterministic response provider generating warm, friendly, natural guide dialogue.
///
/// Serves as the conversational baseline and fallback across all physical assembly tasks (furniture, mechanical, electronics, hybrid).
nonisolated struct DeterministicTutorResponseProvider: TutorResponseProviding {
    nonisolated init() {}
    
    nonisolated func response(for decision: InterventionDecision) -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        switch decision.action {
        case .remainSilent:
            return nil
            
        case .instruct(let step):
            let intros = [
                "Alright! Let's tackle Step \(step.stepOrder): \(step.title). \(step.instruction)",
                "Next up, Step \(step.stepOrder): \(step.title). \(step.instruction)",
                "Here's our next step, Step \(step.stepOrder): \(step.title). \(step.instruction)"
            ]
            let chosen = intros[abs(step.stepOrder.hashValue) % intros.count]
            return TutorResponse(
                text: chosen,
                priority: .normal,
                category: "instruction"
            )
            
        case .confirm(let step):
            let confirmations = [
                "Awesome job! That's locked in place.",
                "Spot on! Step \(step.stepOrder) is complete.",
                "Nicely done! That fits together cleanly.",
                "Boom! That's set up exactly right.",
                "Perfect! That connection is solid."
            ]
            let chosen = confirmations[abs(step.stepOrder.hashValue) % confirmations.count]
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
                prefix = "Almost there! Quick check:"
                priority = .normal
            case .explicit:
                prefix = "Good try! Make sure to align this:"
                priority = .high
            case .detailed:
                prefix = "Don't sweat it, assembly tasks take a little patience. Let's adjust this step-by-step:"
                priority = .high
            }
            return TutorResponse(
                text: "\(prefix) \(description)",
                priority: priority,
                category: "correction"
            )
            
        case .requestBetterView(let explanation):
            return TutorResponse(
                text: "Could you tilt the phone slightly or bring it a little closer? \(explanation)",
                priority: .normal,
                category: "camera_guidance"
            )
            
        case .offerHelp(let step, _):
            return TutorResponse(
                text: "Taking your time on \(step.title)? Totally fine! Whenever you're ready, let me know or check the onscreen highlight.",
                priority: .normal,
                category: "stuck_help"
            )
            
        case .respondToUser(let query):
            return TutorResponse(
                text: "Got it! Regarding \(query), let's keep working through this together.",
                priority: .immediate,
                category: "user_query_response"
            )
        }
    }
}
