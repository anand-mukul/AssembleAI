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
    
    enum CodingKeys: String, CodingKey {
        case id, condition, explanation, correctionAction, severity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let idString = try? container.decode(String.self, forKey: .id) {
            // Support prefix-based IDs like "M0000001-..." by converting 'M' to 'E' for valid hex
            let validHex = idString.replacingOccurrences(of: "^[Mm]", with: "E", options: .regularExpression)
            self.id = UUID(uuidString: validHex) ?? UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = UUID()
        }
        self.condition = try container.decode(String.self, forKey: .condition)
        self.explanation = try container.decode(String.self, forKey: .explanation)
        self.correctionAction = try container.decodeIfPresent(String.self, forKey: .correctionAction) ?? self.explanation
        self.severity = try container.decodeIfPresent(MistakeSeverity.self, forKey: .severity) ?? .moderate
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
