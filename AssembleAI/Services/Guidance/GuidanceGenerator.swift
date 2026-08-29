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

/// Local template-based guidance generator when Foundation Models are unavailable.
nonisolated struct MockGuidanceGenerator: GuidanceGenerating {
    nonisolated init() {}
    
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse {
        switch issue.type {
        case .wrongPosition:
            return GuidanceResponse(
                title: "Wrong position",
                explanation: issue.explanation,
                action: "Shift the component lead over to match the target row."
            )
        case .wrongConnection:
            return GuidanceResponse(
                title: "Wrong connection",
                explanation: issue.explanation,
                action: "Move the jumper wire from 5V to the GND ground rail."
            )
        case .missingComponent:
            return GuidanceResponse(
                title: "Missing component",
                explanation: issue.explanation,
                action: "Insert the required component into the highlighted slot."
            )
        case .insufficientVisualEvidence:
            return GuidanceResponse(
                title: "Need a clearer view",
                explanation: issue.explanation,
                action: "Move closer and ensure the board is clearly illuminated."
            )
        default:
            return GuidanceResponse(
                title: issue.title,
                explanation: issue.explanation,
                action: "Re-check component positioning before retrying scan."
            )
        }
    }
    
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String {
        switch issue.type {
        case .wrongConnection:
            return "GND provides the zero-volt reference path for electrical current flow. Connecting to 5V creates a short circuit risk or improper power bias across the active components."
        case .wrongPosition:
            return "Breadboard rows are connected internally underneath the plastic housing. Placing a lead in Row 14 instead of Row 15 leaves the component disconnected from the rest of the node."
        default:
            return "Correct physical orientation ensures current flows safely through current-limiting elements rather than overloading sensitive semiconductor junctions."
        }
    }
}

#if canImport(FoundationModels)
/// On-device Foundation Models guidance generator using Apple's `FoundationModels` framework (`LanguageModelSession`).
///
/// HARD ARCHITECTURAL RULE:
/// The language model is used ONLY for generating human-readable explanations.
/// It NEVER decides correctness — correctness is determined deterministically by `AssemblyStateComparator`.
@available(iOS 26.0, *)
actor FoundationModelGuidanceGenerator: GuidanceGenerating {
    private let mockFallback = MockGuidanceGenerator()
    
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
                return try await mockFallback.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            }
            
            let validated = GuidanceResponse(
                title: issue.title,
                explanation: text,
                action: "Follow the corrective step above and tap Scan Again."
            )
            
            await GuidanceCache.shared.set(key: cacheKey, response: validated)
            return validated
        } catch {
            return try await mockFallback.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
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
            return text.isEmpty ? try await mockFallback.generateWhyExplanation(step: step, issue: issue) : text
        } catch {
            return try await mockFallback.generateWhyExplanation(step: step, issue: issue)
        }
    }
}
#endif

/// Hybrid guidance generator routing requests to Foundation Models when available on device, falling back to local template generator.
nonisolated struct HybridGuidanceGenerator: GuidanceGenerating {
    private let mockGenerator = MockGuidanceGenerator()
    
    nonisolated init() {}
    
    func generateGuidance(
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState
    ) async throws -> GuidanceResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let generator = FoundationModelGuidanceGenerator()
            do {
                return try await generator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            } catch {
                return try await mockGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
            }
        } else {
            return try await mockGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
        }
        #else
        return try await mockGenerator.generateGuidance(issue: issue, expectedState: expectedState, observedState: observedState)
        #endif
    }
    
    func generateWhyExplanation(
        step: AssemblyStep,
        issue: StateIssue
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let generator = FoundationModelGuidanceGenerator()
            do {
                return try await generator.generateWhyExplanation(step: step, issue: issue)
            } catch {
                return try await mockGenerator.generateWhyExplanation(step: step, issue: issue)
            }
        } else {
            return try await mockGenerator.generateWhyExplanation(step: step, issue: issue)
        }
        #else
        return try await mockGenerator.generateWhyExplanation(step: step, issue: issue)
        #endif
    }
}
