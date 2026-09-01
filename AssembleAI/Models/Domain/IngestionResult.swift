//
//  IngestionResult.swift
//  AssembleAI
//

import Foundation

/// Outcome of an AI-assisted guide ingestion operation.
///
/// Contains the parsed project alongside confidence scores, extraction warnings,
/// and the raw source material for human review.
nonisolated struct IngestionResult: Sendable {
    /// The parsed assembly project (may require user corrections).
    let project: AssemblyProject
    
    /// Overall extraction confidence [0.0 — 1.0].
    let confidence: Double
    
    /// Human-readable warnings about ambiguous or missing data.
    let warnings: [IngestionWarning]
    
    /// The raw input source text that was processed.
    let sourceText: String
    
    /// How long the ingestion took in milliseconds.
    let processingTimeMs: Int
    
    /// Whether the result is considered high-quality enough for direct use without editing.
    var isHighConfidence: Bool { confidence >= 0.8 }
    
    /// Whether the result has critical warnings that require user attention.
    var hasCriticalWarnings: Bool {
        warnings.contains { $0.severity == .critical }
    }
}

/// A warning generated during guide ingestion.
nonisolated struct IngestionWarning: Identifiable, Sendable {
    let id: UUID
    let message: String
    let severity: WarningSeverity
    let affectedField: String?
    
    init(
        id: UUID = UUID(),
        message: String,
        severity: WarningSeverity = .info,
        affectedField: String? = nil
    ) {
        self.id = id
        self.message = message
        self.severity = severity
        self.affectedField = affectedField
    }
    
    nonisolated enum WarningSeverity: String, Sendable {
        case info
        case moderate
        case critical
    }
}

/// Source format of the imported guide material.
nonisolated enum GuideSourceFormat: String, CaseIterable, Sendable {
    case markdown = "Markdown"
    case plainText = "Plain Text"
    case url = "URL"
    case pdf = "PDF"
    
    /// SF Symbol name for this source format.
    var iconName: String {
        switch self {
        case .markdown: return "doc.text"
        case .plainText: return "text.alignleft"
        case .url: return "link"
        case .pdf: return "doc.richtext"
        }
    }
}
