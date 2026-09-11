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
                "Alright, partner! Let's tackle Step \(step.stepOrder): \(step.title). \(step.instruction)",
                "Next up on our workbench, Step \(step.stepOrder): \(step.title). \(step.instruction)",
                "Here's our next move, Step \(step.stepOrder): \(step.title). Let's do this! \(step.instruction)",
                "Time for Step \(step.stepOrder): \(step.title). You're doing great! \(step.instruction)"
            ]
            let chosen = intros[abs(step.stepOrder.hashValue) % intros.count]
            return TutorResponse(
                text: chosen,
                priority: .normal,
                category: "instruction"
            )
            
        case .confirm(let step):
            let confirmations = [
                "Boom! Nailed it—well, locked it in, technically! Step \(step.stepOrder) is complete.",
                "Look at that fit! That's what I call craftsmanship. Step \(step.stepOrder) is verified.",
                "Spot on, my friend! That connection is solid as a rock.",
                "High five! That slotted together like a dream. Step \(step.stepOrder) done!",
                "Flawless execution! You're making this look easy."
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
                prefix = "So close! Quick eagle-eye check:"
                priority = .normal
            case .explicit:
                prefix = "Hold up, friend! That piece took a little detour:"
                priority = .high
            case .detailed:
                prefix = "Don't sweat it—every master builder does a quick nudge. Let's fix this step-by-step:"
                priority = .high
            }
            return TutorResponse(
                text: "\(prefix) \(description)",
                priority: priority,
                category: "correction"
            )
            
        case .requestBetterView(let explanation):
            return TutorResponse(
                text: "Give me a slightly better peek, friend! Tilt the phone a bit or bring it closer so I can see what we're working with. \(explanation)",
                priority: .normal,
                category: "camera_guidance"
            )
            
        case .offerHelp(let step, _):
            return TutorResponse(
                text: "Taking a breather on \(step.title)? Smart move—measure twice, build once! Whenever you're ready, let me know or check the onscreen highlight.",
                priority: .normal,
                category: "stuck_help"
            )
            
        case .respondToUser(let query):
            return TutorResponse(
                text: "I hear you! Regarding \(query), let's keep working through this together.",
                priority: .immediate,
                category: "user_query_response"
            )
        }
    }
}
