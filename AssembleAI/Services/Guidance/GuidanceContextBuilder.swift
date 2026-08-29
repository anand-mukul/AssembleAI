//
//  GuidanceContextBuilder.swift
//  AssembleAI
//

import Foundation

/// Helper building structured, strict context prompts for Apple Foundation Models.
nonisolated struct GuidanceContextBuilder: Sendable {
    
    /// Constructs a strict, grounded system context for model guidance generation.
    nonisolated static func buildContext(
        step: AssemblyStep,
        issue: StateIssue,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState,
        level: GuidanceLevel = .concise,
        attemptNumber: Int = 1
    ) -> String {
        let expectedDesc = expectedState.requiredComponents.map(\.name).joined(separator: ", ")
        let observedDesc = observedState.detectedComponents.map(\.name).joined(separator: ", ")
        
        let adaptiveNotice = attemptNumber >= 2
            ? "NOTICE: The user has attempted this step \(attemptNumber) times. Provide extra clear, explicit physical instructions."
            : ""
        
        return """
        SYSTEM INSTRUCTION:
        You are the guidance assistant inside AssembleAI.
        Your job is to explain an already-detected assembly issue in simple, actionable language.
        Do not determine whether the physical assembly is correct.
        Do not invent components, positions, connections, or measurements.
        Use only the supplied expected state, observed state, and detected issue.
        
        TASK CONTEXT:
        Step: \(step.stepOrder) — \(step.title)
        Instruction: \(step.instruction)
        Guidance Level: \(level.rawValue)
        \(adaptiveNotice)
        
        DETECTED ISSUE:
        Issue Type: \(issue.type.rawValue)
        Title: \(issue.title)
        Explanation: \(issue.explanation)
        
        EXPECTED PHYSICAL STATE:
        \(expectedDesc.isEmpty ? step.title : expectedDesc)
        
        OBSERVED PHYSICAL STATE:
        \(observedDesc.isEmpty ? "Uncertain / Unidentified component placement" : observedDesc)
        
        OUTPUT REQUIREMENT:
        Provide a concise 1-2 sentence explanation and 1 explicit physical action step.
        """
    }
    
    /// Constructs a prompt for the contextual "Why is this wrong?" bottom sheet.
    nonisolated static func buildWhyContext(
        step: AssemblyStep,
        issue: StateIssue
    ) -> String {
        return """
        Explain in 2 simple sentences why \(issue.title) (\(issue.explanation)) is problematic for physical assembly step "\(step.title)". Ground your explanation strictly in basic electrical/mechanical principles.
        """
    }
}
