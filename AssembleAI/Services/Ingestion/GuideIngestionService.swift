//
//  GuideIngestionService.swift
//  AssembleAI
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Protocol

/// Service protocol for converting unstructured guide text into structured `AssemblyProject` packages.
///
/// Implementations include:
/// - `MarkdownGuideParser`: Deterministic parser for structured markdown tutorials.
/// - `FoundationModelIngestionService`: AI-assisted extraction using Apple Foundation Models.
/// - `DeterministicIngestionFallback`: Template-based fallback when no AI model is available.
protocol GuideIngestionServiceProtocol: Sendable {
    /// Parses raw guide text into a structured assembly project.
    /// - Parameters:
    ///   - text: The raw guide content (markdown, plain text, or extracted PDF text).
    ///   - format: The source format of the input.
    ///   - domain: The expected assembly domain (electronics, physical, or hybrid).
    /// - Returns: An `IngestionResult` containing the parsed project and quality metadata.
    func ingest(
        text: String,
        format: GuideSourceFormat,
        domain: AssemblyDomain
    ) async throws -> IngestionResult
}

// MARK: - Ingestion Errors

enum GuideIngestionError: LocalizedError {
    case emptyInput
    case parsingFailed(String)
    case noStepsExtracted
    case modelUnavailable
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "The provided guide text is empty."
        case .parsingFailed(let reason):
            return "Failed to parse guide: \(reason)"
        case .noStepsExtracted:
            return "No assembly steps could be extracted from the provided text."
        case .modelUnavailable:
            return "On-device language model is not available on this device."
        }
    }
}

// MARK: - Foundation Models Ingestion Service

#if canImport(FoundationModels)
/// AI-assisted guide ingestion using Apple Foundation Models.
///
/// Sends the raw guide text to the on-device language model with a structured extraction prompt.
/// The model returns a JSON representation of the project that is decoded into an `AssemblyProject`.
@available(iOS 26.0, *)
actor FoundationModelIngestionService: GuideIngestionServiceProtocol {
    
    func ingest(
        text: String,
        format: GuideSourceFormat,
        domain: AssemblyDomain
    ) async throws -> IngestionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GuideIngestionError.emptyInput }
        
        let startTime = Date()
        let prompt = GuideIngestionPrompts.buildExtractionPrompt(
            guideText: trimmed,
            format: format,
            domain: domain
        )
        
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        let responseText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let processingMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        // Extract JSON block from response
        let jsonString = extractJSONBlock(from: responseText)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GuideIngestionError.parsingFailed("Could not encode model response as UTF-8 data.")
        }
        
        // Decode with snake_case strategy matching our schema
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let project: AssemblyProject
        do {
            project = try decoder.decode(AssemblyProject.self, from: jsonData)
        } catch {
            throw GuideIngestionError.parsingFailed("JSON decoding failed: \(error.localizedDescription)")
        }
        
        guard !project.steps.isEmpty else {
            throw GuideIngestionError.noStepsExtracted
        }
        
        // Generate warnings from validation
        var warnings: [IngestionWarning] = []
        let diagnostics = ProjectPackageValidator.diagnose(project)
        for diagnostic in diagnostics {
            warnings.append(IngestionWarning(
                message: diagnostic,
                severity: diagnostic.contains("totalSteps") ? .moderate : .info,
                affectedField: "schema"
            ))
        }
        
        // Estimate confidence based on extracted data quality
        let confidence = estimateConfidence(project: project, warnings: warnings)
        
        return IngestionResult(
            project: project,
            confidence: confidence,
            warnings: warnings,
            sourceText: trimmed,
            processingTimeMs: processingMs
        )
    }
    
    /// Extracts a JSON object from a model response that may contain markdown code fences.
    private func extractJSONBlock(from text: String) -> String {
        // Try to extract from ```json ... ``` fences
        if let jsonRange = text.range(of: "```json", options: .caseInsensitive),
           let endRange = text.range(of: "```", options: .caseInsensitive, range: jsonRange.upperBound..<text.endIndex) {
            return String(text[jsonRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to extract from ``` ... ```
        if let startRange = text.range(of: "```"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to find raw JSON object
        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}") {
            return String(text[openBrace...closeBrace])
        }
        
        return text
    }
    
    /// Estimates extraction confidence based on project completeness.
    private func estimateConfidence(project: AssemblyProject, warnings: [IngestionWarning]) -> Double {
        var score: Double = 0.5
        
        // Steps extracted
        if !project.steps.isEmpty { score += 0.15 }
        if project.steps.count >= 3 { score += 0.05 }
        
        // Components extracted
        if !project.components.isEmpty { score += 0.1 }
        
        // Visual contracts present
        let stepsWithContracts = project.steps.filter { $0.visualContract != nil }.count
        if stepsWithContracts > 0 { score += 0.1 }
        
        // Description and metadata
        if !project.description.isEmpty { score += 0.05 }
        if project.estimatedMinutes > 0 { score += 0.05 }
        
        // Penalty for warnings
        let criticalCount = warnings.filter { $0.severity == .critical }.count
        score -= Double(criticalCount) * 0.1
        
        return max(0.1, min(1.0, score))
    }
}
#endif

// MARK: - Deterministic Fallback

/// Template-based fallback ingestion that works without an AI model.
/// Delegates to `MarkdownGuideParser` for structured content, or creates a minimal
/// single-step project from plain text.
struct DeterministicIngestionFallback: GuideIngestionServiceProtocol {
    
    private let markdownParser = MarkdownGuideParser()
    
    func ingest(
        text: String,
        format: GuideSourceFormat,
        domain: AssemblyDomain
    ) async throws -> IngestionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GuideIngestionError.emptyInput }
        
        let startTime = Date()
        
        // Try markdown parsing first
        if format == .markdown || text.contains("## ") || text.contains("# ") {
            let result = try markdownParser.parse(text: trimmed, domain: domain)
            return result
        }
        
        // For plain text, create a minimal project from line-by-line instructions
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { throw GuideIngestionError.noStepsExtracted }
        
        // First line as title, rest as steps
        let title = lines[0]
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let stepLines = lines.dropFirst().enumerated().map { index, line in
            ProjectStepSummary(
                stepOrder: index + 1,
                title: "Step \(index + 1)",
                instruction: line
            )
        }
        
        let project = AssemblyProject(
            title: title.isEmpty ? "Imported Project" : title,
            category: domain == .electronics ? "Electronics" : "Assembly",
            difficulty: .beginner,
            estimatedMinutes: max(5, stepLines.count * 3),
            totalSteps: max(1, stepLines.count),
            steps: stepLines.isEmpty
                ? [ProjectStepSummary(stepOrder: 1, title: "Step 1", instruction: title)]
                : stepLines,
            domain: domain
        )
        
        let processingMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        return IngestionResult(
            project: project,
            confidence: 0.4,
            warnings: [
                IngestionWarning(
                    message: "Plain text import produces minimal structure. Consider using markdown format with headings for better extraction.",
                    severity: .moderate,
                    affectedField: "steps"
                )
            ],
            sourceText: trimmed,
            processingTimeMs: processingMs
        )
    }
}

// MARK: - Factory

/// Resolves the appropriate ingestion service based on device capabilities.
enum GuideIngestionServiceFactory {
    static func resolve() -> GuideIngestionServiceProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelIngestionService()
        }
        #endif
        return DeterministicIngestionFallback()
    }
}
