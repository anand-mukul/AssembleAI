//
//  GuidanceGenerator.swift
//  AssembleAI
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Structured natural-language guidance response produced by the guidance engine.
nonisolated struct GuidanceResponse: Hashable, Codable, Equatable, Sendable {
    let title: String
    let explanation: String
    let action: String
}

/// Protocol for generating human-readable explanation and adaptive remediation guidance.
protocol GuidanceGenerating: Sendable {
    /// Generates structured natural-language guidance for a physical state issue.
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse
    
    /// Generates a contextual explanation answering "Why is this wrong?" for an issue.
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String
}

/// Rule-based deterministic guidance generator providing template explanations when on-device Foundation Models are unavailable.
nonisolated struct RuleBasedGuidanceGenerator: GuidanceGenerating {
    nonisolated init() {}
    
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse {
        switch issue.type {
        case .wrongPosition:
            let targetName = expectedState.requiredComponents.first?.name ?? "component"
            return GuidanceResponse(
                title: issue.title.isEmpty ? "Wrong position" : issue.title,
                explanation: issue.explanation,
                action: "Reposition the \(targetName) to match the target placement."
            )
        case .wrongConnection:
            let action: String
            if let reqConn = expectedState.requiredConnections.first {
                action = "Connect from \(reqConn.from) to \(reqConn.to)."
            } else {
                action = "Verify the connection matches the reference step instruction."
            }
            return GuidanceResponse(
                title: issue.title.isEmpty ? "Wrong connection" : issue.title,
                explanation: issue.explanation,
                action: action
            )
        case .missingComponent:
            let missingName = expectedState.requiredComponents.first(where: { req in
                !observedState.detectedComponents.contains(where: { $0.identifier == req.identifier || $0.name.localizedCaseInsensitiveContains(req.name) })
            })?.name
            let actionText = missingName != nil ? "Place \(missingName!) into the workspace." : "Insert the required component into the target area."
            return GuidanceResponse(
                title: issue.title.isEmpty ? "Missing component" : issue.title,
                explanation: issue.explanation,
                action: actionText
            )
        case .insufficientVisualEvidence:
            return GuidanceResponse(
                title: "Need a clearer view",
                explanation: issue.explanation,
                action: "Move closer and ensure your workspace is well lit."
            )
        default:
            return GuidanceResponse(
                title: issue.title.isEmpty ? "Needs adjustment" : issue.title,
                explanation: issue.explanation,
                action: "Re-check component positioning before retrying scan."
            )
        }
    }
    
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String {
        // 1. Check step common mistakes for a matching condition or text
        let issueLower = (issue.explanation + " " + issue.title).lowercased()
        if let matchedMistake = step.commonMistakes.first(where: { mistake in
            let cond = mistake.condition.lowercased()
            let expl = mistake.explanation.lowercased()
            return issueLower.contains(cond) || issueLower.contains(expl) ||
                   (cond.contains("flip") && issueLower.contains("rough")) ||
                   (cond.contains("dowel") && issueLower.contains("dowel")) ||
                   (cond.contains("panel") && issueLower.contains("panel")) ||
                   (cond.contains("cam") && issueLower.contains("cam")) ||
                   (cond.contains("row") && issueLower.contains("row"))
        }) {
            return "\(matchedMistake.explanation) \(matchedMistake.correctionAction)"
        }
        
        // 2. Identify physical domain vs electronics
        let isPhysical: Bool
        if let contract = step.visualContract {
            isPhysical = contract.hasPhysicalConstraints && !contract.hasElectronicsConstraints
        } else {
            let titleLower = step.title.lowercased()
            isPhysical = titleLower.contains("shelf") || titleLower.contains("panel") ||
                         titleLower.contains("dowel") || titleLower.contains("cam") ||
                         titleLower.contains("screw") || titleLower.contains("bolt") ||
                         titleLower.contains("wood") || titleLower.contains("furniture") ||
                         titleLower.contains("bracket") || titleLower.contains("board") ||
                         titleLower.contains("nail")
        }
        
        if isPhysical {
            let textLower = (step.title + " " + issue.title + " " + issue.explanation).lowercased()
            if textLower.contains("dowel") {
                return "Wooden dowels provide structural shear alignment between side panels and shelves. Partial seating or incorrect hole alignment creates joint racking under mechanical load."
            } else if textLower.contains("cam") || textLower.contains("lock") {
                return "Cam lock fasteners pull the joint flush when rotated 180° clockwise over the cam bolt head. Unlocked or loose cams leave panels loose and susceptible to structural collapse."
            } else if textLower.contains("back") || textLower.contains("nail") {
                return "The back panel provides diagonal squaring and shear rigidity for the entire cabinet. Placing the smooth laminated side outward protects the backing board against environmental warping."
            } else if textLower.contains("shelf") || textLower.contains("panel") {
                return "Proper orientation ensures pre-drilled hardware holes align with the matching side panel. Inverting or reversing the panel misaligns the internal cam bolt receptors."
            } else {
                return "Accurate fastener depth and alignment ensures each structural joint achieves full rated clamping force and prevents joint play."
            }
        } else {
            // Electronics circuit domain
            switch issue.type {
            case .wrongConnection:
                let textLower = (issue.explanation + " " + issue.title).lowercased()
                if textLower.contains("gnd") || textLower.contains("ground") || textLower.contains("5v") || textLower.contains("vcc") {
                    return "GND provides the zero-volt reference path for electrical current flow. Connecting to power rails or incorrect pins creates short circuit risks or improper component bias."
                } else {
                    return "Correct circuit routing ensures voltage and signals flow along intended paths. An incorrect pin connection prevents proper operation or can damage sensitive nodes."
                }
            case .wrongPosition:
                return "Circuit and breadboard tie-points route specific signals within each pin group. Misaligning component pins leaves nodes electrically open or shorted to adjacent nets."
            case .missingComponent:
                return "Each circuit component fulfills an essential role in the signal or power path. Omitting this component leaves the circuit loop incomplete."
            default:
                return "Correct component orientation ensures current flows safely through polarized semiconductors rather than overloading sensitive PN junctions."
            }
        }
    }
}

/// Backwards-compatible alias for unit test suites
typealias MockGuidanceGenerator = RuleBasedGuidanceGenerator

#if canImport(FoundationModels)
/// On-device Foundation Models guidance generator using Apple's `FoundationModels` framework (`LanguageModelSession`).
///
/// HARD ARCHITECTURAL RULE:
/// The language model is used ONLY for generating human-readable explanations.
/// It NEVER decides correctness — correctness is determined deterministically by `AssemblyStateComparator`.
@available(iOS 18.0, *)
actor FoundationModelGuidanceGenerator: GuidanceGenerating {
    private let fallback = RuleBasedGuidanceGenerator()
    
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse {
        // 1. Cache Lookup
        let cacheKey = GuidanceCache.makeKey(stepID: expectedState.stepID, issueType: issue.type, level: .concise)
        if let cached = await GuidanceCache.shared.get(key: cacheKey) {
            return cached
        }
        
        let prompt = GuidanceContextBuilder.buildContext(
            step: AssemblyStep(projectId: expectedState.stepID, stepOrder: expectedState.stepOrder, title: issue.title, instruction: issue.explanation),
            issue: issue,
            expectedState: expectedState,
            observedState: observedState
        )
        
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty else {
                return try await fallback.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            }
            
            let validated = GuidanceResponse(
                title: issue.title,
                explanation: text,
                action: "Follow the corrective step above and tap Scan Again."
            )
            
            await GuidanceCache.shared.set(key: cacheKey, response: validated)
            return validated
        } catch {
            return try await fallback.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
        }
    }
    
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String {
        let prompt = GuidanceContextBuilder.buildWhyContext(step: step, issue: issue)
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? try await fallback.generateWhyExplanation(step: step, issue: issue) : text
        } catch {
            return try await fallback.generateWhyExplanation(step: step, issue: issue)
        }
    }
}
#endif

/// Hybrid guidance generator routing requests to Foundation Models when available on device, falling back to local template generator.
nonisolated struct HybridGuidanceGenerator: GuidanceGenerating {
    private let ruleBasedGenerator = RuleBasedGuidanceGenerator()
    
    nonisolated init() {}
    
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let generator = FoundationModelGuidanceGenerator()
            do {
                return try await generator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            } catch {
                return try await ruleBasedGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            }
        } else {
            return try await ruleBasedGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
        }
        #else
        return try await ruleBasedGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
        #endif
    }
    
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let generator = FoundationModelGuidanceGenerator()
            do {
                return try await generator.generateWhyExplanation(step: step, issue: issue)
            } catch {
                return try await ruleBasedGenerator.generateWhyExplanation(step: step, issue: issue)
            }
        } else {
            return try await ruleBasedGenerator.generateWhyExplanation(step: step, issue: issue)
        }
        #else
        return try await ruleBasedGenerator.generateWhyExplanation(step: step, issue: issue)
        #endif
    }
}
