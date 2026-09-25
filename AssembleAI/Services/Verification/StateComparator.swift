//
//  StateComparator.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Three-state outcome status for physical assembly verification.
nonisolated enum ComparisonStatus: String, Codable, Hashable, Equatable, Sendable {
    case correct
    case incorrect
    case uncertain
}

/// Category of physical assembly mismatch issue.
nonisolated enum StateIssueType: String, Codable, Hashable, Equatable, Sendable {
    case missingComponent
    case unexpectedComponent
    case wrongPosition
    case missingConnection
    case wrongConnection
    case uncertainDetection
    case insufficientVisualEvidence
}

/// Severity classification for a physical assembly issue.
nonisolated enum IssueSeverity: String, Codable, Hashable, Equatable, Sendable {
    case low
    case medium
    case high
    case critical
}

/// Specific physical discrepancy discovered during state comparison.
nonisolated struct StateIssue: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: UUID
    let type: StateIssueType
    let title: String
    let explanation: String
    let severity: IssueSeverity
    
    init(
        id: UUID = UUID(),
        type: StateIssueType,
        title: String,
        explanation: String,
        severity: IssueSeverity = .high
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.explanation = explanation
        self.severity = severity
    }
}

/// Structured outcome comparing expected state against observed state.
nonisolated struct StateComparison: Hashable, Codable, Equatable, Sendable {
    let status: ComparisonStatus
    let confidence: Double
    let issues: [StateIssue]
    let matchedComponents: [String]
}

/// Configurable confidence policy thresholds.
///
/// NOTE: These thresholds are **prototype parameters** for development testing,
/// not validated research results.
nonisolated struct VerificationConfiguration: Hashable, Codable, Equatable, Sendable {
    /// Minimum visual evidence confidence required to perform state comparison (below this yields `.uncertain`).
    let minimumEvidenceConfidence: Double
    /// Minimum confidence required to pass verification as `.correct`.
    let minimumCorrectConfidence: Double
    
    init(minimumEvidenceConfidence: Double = 0.50, minimumCorrectConfidence: Double = 0.75) {
        self.minimumEvidenceConfidence = minimumEvidenceConfidence
        self.minimumCorrectConfidence = minimumCorrectConfidence
    }
}

/// Deterministic state comparison engine evaluating expected vs observed physical states.
nonisolated struct AssemblyStateComparator: Sendable {
    let configuration: VerificationConfiguration
    
    init(configuration: VerificationConfiguration = VerificationConfiguration()) {
        self.configuration = configuration
    }
    
    /// Evaluates expected physical state against observed state.
    func compare(
        expected: ExpectedAssemblyState,
        observed: ObservedAssemblyState,
        hasAcousticCorroboration: Bool = false
    ) -> StateComparison {
        // Effective confidence factoring multimodal acoustic snap corroboration
        let boostedConfidence = hasAcousticCorroboration ? min(0.98, observed.overallConfidence + 0.15) : observed.overallConfidence
        
        // 1. Evidence Check: If observed confidence is below threshold, return `.uncertain`
        if boostedConfidence < configuration.minimumEvidenceConfidence {
            return StateComparison(
                status: .uncertain,
                confidence: boostedConfidence,
                issues: [
                    StateIssue(
                        type: .insufficientVisualEvidence,
                        title: "Need a clearer view",
                        explanation: "Visual evidence confidence (\(Int(boostedConfidence * 100))%) is below the required threshold.",
                        severity: .medium
                    )
                ],
                matchedComponents: []
            )
        }
        
        var issues: [StateIssue] = []
        var matchedComponents: [String] = []
        
        // 2. Component Presence Check (Universal Semantic & Category-Aware Matching)
        for reqComp in expected.requiredComponents {
            let matches = observed.detectedComponents.filter { obs in
                if let id = obs.identifier {
                    if id.localizedCaseInsensitiveContains(reqComp.identifier) || reqComp.identifier.localizedCaseInsensitiveContains(id) {
                        return true
                    }
                }
                if obs.name.localizedCaseInsensitiveContains(reqComp.name) || reqComp.name.localizedCaseInsensitiveContains(obs.name) {
                    return true
                }
                
                // Universal token-aware category matching for physical electronics & mechanical hardware (H-2)
                for category in HardwareCategory.allCases {
                    let reqMatches = matchesComponentCategory(text: reqComp.name, identifier: reqComp.identifier, keywords: category.keywords)
                    let obsMatches = matchesComponentCategory(text: obs.name, identifier: obs.identifier ?? "", keywords: category.keywords)
                    if reqMatches && obsMatches {
                        return true
                    }
                }
                
                return false
            }
            
            if matches.isEmpty {
                issues.append(
                    StateIssue(
                        type: .missingComponent,
                        title: "Missing \(reqComp.name)",
                        explanation: "Expected \(reqComp.name) was not detected in the target workspace area.",
                        severity: .high
                    )
                )
            } else {
                matchedComponents.append(reqComp.name)
            }
        }
        
        // 3. Position Verification (Physical spatial placements & electronics pin positions)
        if !expected.requiredPositions.isEmpty {
            for reqPos in expected.requiredPositions {
                let matchingPos = observed.detectedPositions.first { obsPos in
                    obsPos.componentID.localizedCaseInsensitiveContains(reqPos.componentID) ||
                    reqPos.componentID.localizedCaseInsensitiveContains(obsPos.componentID) ||
                    obsPos.detectedDescription.localizedCaseInsensitiveContains(reqPos.targetDescription) ||
                    reqPos.targetDescription.localizedCaseInsensitiveContains(obsPos.detectedDescription)
                }
                
                let compMatched = observed.detectedComponents.contains { c in
                    let idMatch = c.identifier.map { reqPos.componentID.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(reqPos.componentID) } ?? false
                    return idMatch || c.name.localizedCaseInsensitiveContains(reqPos.componentID)
                }
                
                if matchingPos == nil && !compMatched {
                    if !matchedComponents.contains(where: { $0.localizedCaseInsensitiveContains(reqPos.componentID) }) {
                        issues.append(
                            StateIssue(
                                type: .wrongPosition,
                                title: "Placement Required",
                                explanation: "Position \(reqPos.componentID) at \(reqPos.targetDescription).",
                                severity: .medium
                            )
                        )
                    }
                }
            }
        }
        
        // 4. Unexpected Component Check
        for obsComp in observed.detectedComponents {
            if obsComp.identifier == nil && obsComp.confidence <= 0.40 {
                issues.append(
                    StateIssue(
                        type: .unexpectedComponent,
                        title: "Unidentified Object",
                        explanation: "An unexpected or unrecognized object (\(obsComp.name)) was detected near the target area.",
                        severity: .low
                    )
                )
            }
        }
        
        // 5. Connection Rail Check (Circuits, Wiring Harnesses, Plumbing)
        for reqConn in expected.requiredConnections {
            let matchingConn = observed.detectedConnections.first { obs in
                obs.from.localizedCaseInsensitiveContains(reqConn.from) && obs.to.localizedCaseInsensitiveContains(reqConn.to)
            }
            
            if matchingConn == nil {
                let wrongConn = observed.detectedConnections.first
                if let wrong = wrongConn {
                    issues.append(
                        StateIssue(
                            type: .wrongConnection,
                            title: "Wrong Connection",
                            explanation: "Connected to \(wrong.from) instead of \(reqConn.from).",
                            severity: .high
                        )
                    )
                } else {
                    issues.append(
                        StateIssue(
                            type: .missingConnection,
                            title: "Missing Connection",
                            explanation: "Required connection from \(reqConn.from) to \(reqConn.to) is missing.",
                            severity: .high
                        )
                    )
                }
            }
        }
        
        // 6. Final Status Determination
        let hasHighSeverityIssues = issues.contains { $0.severity == .high || $0.severity == .critical }
        let status: ComparisonStatus
        
        if hasHighSeverityIssues {
            status = .incorrect
        } else if !issues.isEmpty {
            status = .incorrect
        } else if boostedConfidence >= configuration.minimumCorrectConfidence {
            status = .correct
        } else {
            status = .uncertain
        }
        
        return StateComparison(
            status: status,
            confidence: boostedConfidence,
            issues: issues,
            matchedComponents: matchedComponents
        )
    }
}

// MARK: - Hardware Category Token Matching (H-2)

private nonisolated enum HardwareCategory: CaseIterable {
    case resistor
    case led
    case capacitor
    case integratedCircuit
    case wire
    case dowel
    case camLock
    case fastener
    case structuralPanel
    case bracket
    case conduit
    
    nonisolated var keywords: [String] {
        switch self {
        case .resistor: return ["resistor", "res", "ohm", "220", "10k", "1k"]
        case .led: return ["led", "diode", "anode", "cathode"]
        case .capacitor: return ["capacitor", "cap", "electrolytic", "ceramic", "uf", "100u"]
        case .integratedCircuit: return ["ic", "chip", "dip", "microcontroller", "atmega", "555"]
        case .wire: return ["wire", "jumper", "cable", "lead"]
        case .dowel: return ["dowel", "peg"]
        case .camLock: return ["cam", "camlock", "disc"]
        case .fastener: return ["screw", "bolt", "nut", "washer", "nail", "fastener"]
        case .structuralPanel: return ["panel", "shelf", "plank", "board"]
        case .bracket: return ["bracket", "mount", "frame", "hinge"]
        case .conduit: return ["pipe", "hose", "tube", "manifold", "valve"]
        }
    }
}

private nonisolated func matchesComponentCategory(text: String, identifier: String, keywords: [String]) -> Bool {
    let lowerText = text.lowercased()
    let lowerId = identifier.lowercased()
    
    let words = Set(lowerText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
    let idWords = Set(lowerId.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
    let allTokens = words.union(idWords)
    
    for kw in keywords {
        if allTokens.contains(kw) { return true }
        for token in allTokens {
            if token == kw { return true }
            if kw.count >= 4 && token.hasPrefix(kw) { return true }
            if (kw == "res" || kw == "cap" || kw == "ic") && (token == kw || token.hasPrefix(kw + "_") || token.hasPrefix(kw + "-")) {
                return true
            }
        }
    }
    return false
}

