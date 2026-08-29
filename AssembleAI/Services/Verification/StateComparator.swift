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
    func compare(expected: ExpectedAssemblyState, observed: ObservedAssemblyState) -> StateComparison {
        // 1. Evidence Check: If observed confidence is below threshold, return `.uncertain`
        if observed.overallConfidence < configuration.minimumEvidenceConfidence {
            return StateComparison(
                status: .uncertain,
                confidence: observed.overallConfidence,
                issues: [
                    StateIssue(
                        type: .insufficientVisualEvidence,
                        title: "Need a clearer view",
                        explanation: "Visual evidence confidence (\(Int(observed.overallConfidence * 100))%) is below required threshold. Move closer and ensure your workspace is well lit.",
                        severity: .medium
                    )
                ],
                matchedComponents: []
            )
        }
        
        var issues: [StateIssue] = []
        var matchedComponents: [String] = []
        
        // 2. Component Presence Check
        for reqComp in expected.requiredComponents {
            let matches = observed.detectedComponents.filter { obs in
                obs.identifier == reqComp.identifier || obs.name.localizedCaseInsensitiveContains(reqComp.name)
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
        
        // 3. Unexpected Component Check
        for obsComp in observed.detectedComponents {
            if obsComp.identifier == nil {
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
        
        // 4. Connection Rail Check
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
                            explanation: "Wire is connected to \(wrong.from) instead of \(reqConn.from).",
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
        
        // 5. Final Status Determination
        let hasHighSeverityIssues = issues.contains { $0.severity == .high || $0.severity == .critical }
        let status: ComparisonStatus
        
        if hasHighSeverityIssues {
            status = .incorrect
        } else if !issues.isEmpty {
            status = .incorrect
        } else if observed.overallConfidence >= configuration.minimumCorrectConfidence {
            status = .correct
        } else {
            status = .uncertain
        }
        
        return StateComparison(
            status: status,
            confidence: observed.overallConfidence,
            issues: issues,
            matchedComponents: matchedComponents
        )
    }
}
