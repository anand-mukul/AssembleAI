//
//  CommonMistake.swift
//  AssembleAI
//

import Foundation

/// A documented common mistake for a specific assembly step.
/// Used by the verification engine and voice tutor to provide targeted,
/// actionable remediation guidance when a known error pattern is detected.
nonisolated struct CommonMistake: Identifiable, Codable, Hashable, Equatable, Sendable {
    let id: UUID
    
    /// Machine-detectable condition description (e.g., "Row 14 bridging", "reversed polarity").
    let condition: String
    
    /// Human-readable explanation delivered via voice and on-screen guidance.
    let explanation: String
    
    /// Specific corrective action the user should take.
    let correctionAction: String
    
    /// Severity level indicating how critical this mistake is.
    let severity: MistakeSeverity
    
    init(
        id: UUID = UUID(),
        condition: String,
        explanation: String,
        correctionAction: String = "",
        severity: MistakeSeverity = .moderate
    ) {
        self.id = id
        self.condition = condition
        self.explanation = explanation
        self.correctionAction = correctionAction.isEmpty ? explanation : correctionAction
        self.severity = severity
    }
}

/// Severity classification for common assembly mistakes.
nonisolated enum MistakeSeverity: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    /// Minor cosmetic or non-functional issue (e.g., wire color mismatch).
    case minor = "minor"
    
    /// Functional issue that will prevent correct operation (e.g., wrong row).
    case moderate = "moderate"
    
    /// Critical safety issue (e.g., reversed polarity on electrolytic capacitor, short circuit risk).
    case critical = "critical"
}
