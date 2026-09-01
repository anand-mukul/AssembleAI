//
//  MarkdownGuideParser.swift
//  AssembleAI
//

import Foundation

/// Deterministic parser that converts structured markdown tutorials into `AssemblyProject` packages.
///
/// Expected markdown structure:
/// ```markdown
/// # Project Title
///
/// Optional description paragraph.
///
/// ## Components (or "Parts" or "Materials" or "Bill of Materials" or "BOM")
/// - Component Name — detail (optional: x2, quantity: 3)
/// - Another Component — detail
///
/// ## Step 1: Step Title (or "## 1. Step Title")
/// Step instruction text.
///
/// > **Warning**: Common mistake description.
///
/// ## Step 2: Step Title
/// More instruction text.
/// ```
struct MarkdownGuideParser {
    
    // MARK: - Parsing
    
    /// Parses structured markdown text into an `IngestionResult`.
    func parse(text: String, domain: AssemblyDomain = .electronics) throws -> IngestionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GuideIngestionError.emptyInput }
        
        let startTime = Date()
        let lines = trimmed.components(separatedBy: .newlines)
        
        // Extract title from first H1
        let title = extractTitle(from: lines)
        
        // Extract description (lines between title and first H2)
        let description = extractDescription(from: lines)
        
        // Extract components from BOM section
        let components = extractComponents(from: lines)
        
        // Extract steps from H2 sections
        let steps = extractSteps(from: lines)
        
        guard !steps.isEmpty else {
            throw GuideIngestionError.noStepsExtracted
        }
        
        // Infer difficulty from step count and component complexity
        let difficulty = inferDifficulty(steps: steps, components: components)
        
        // Estimate time
        let estimatedMinutes = max(5, steps.count * 3 + components.count)
        
        let project = AssemblyProject(
            title: title.isEmpty ? "Imported Guide" : title,
            subtitle: String(description.prefix(100)),
            category: domain == .electronics ? "Electronics" : "Assembly",
            difficulty: difficulty,
            estimatedMinutes: estimatedMinutes,
            totalSteps: steps.count,
            description: description,
            components: components,
            steps: steps,
            domain: domain
        )
        
        let processingMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        // Generate quality warnings
        var warnings: [IngestionWarning] = []
        
        if components.isEmpty {
            warnings.append(IngestionWarning(
                message: "No components section found. Add a '## Components' or '## Parts' heading with a bulleted list.",
                severity: .moderate,
                affectedField: "components"
            ))
        }
        
        let stepsWithoutInstructions = steps.filter { $0.instruction.trimmingCharacters(in: .whitespaces).isEmpty }
        if !stepsWithoutInstructions.isEmpty {
            warnings.append(IngestionWarning(
                message: "\(stepsWithoutInstructions.count) step(s) have empty instructions.",
                severity: .moderate,
                affectedField: "steps"
            ))
        }
        
        // Confidence based on extraction quality
        var confidence: Double = 0.5
        if !title.isEmpty { confidence += 0.1 }
        if !description.isEmpty { confidence += 0.05 }
        if !components.isEmpty { confidence += 0.15 }
        if steps.count >= 3 { confidence += 0.1 }
        if steps.allSatisfy({ !$0.instruction.isEmpty }) { confidence += 0.1 }
        
        return IngestionResult(
            project: project,
            confidence: min(1.0, confidence),
            warnings: warnings,
            sourceText: trimmed,
            processingTimeMs: processingMs
        )
    }
    
    // MARK: - Title Extraction
    
    private func extractTitle(from lines: [String]) -> String {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                return trimmed
                    .replacingOccurrences(of: "# ", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        // Fallback: first non-empty line
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    // MARK: - Description Extraction
    
    private func extractDescription(from lines: [String]) -> String {
        var foundTitle = false
        var descriptionLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                foundTitle = true
                continue
            }
            
            if foundTitle {
                if trimmed.hasPrefix("## ") {
                    break // Hit the first section
                }
                if !trimmed.isEmpty {
                    descriptionLines.append(trimmed)
                }
            }
        }
        
        return descriptionLines.joined(separator: " ")
    }
    
    // MARK: - Components Extraction
    
    private func extractComponents(from lines: [String]) -> [ComponentRequirement] {
        let bomHeadings = ["components", "parts", "materials", "bill of materials", "bom", "you will need", "what you need"]
        
        var inBOMSection = false
        var components: [ComponentRequirement] = []
        var partCounter = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            
            // Check for BOM section heading
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                let headingText = trimmed
                    .replacingOccurrences(of: "### ", with: "")
                    .replacingOccurrences(of: "## ", with: "")
                    .lowercased()
                    .trimmingCharacters(in: .whitespaces)
                
                inBOMSection = bomHeadings.contains(where: { headingText.contains($0) })
                continue
            }
            
            // Parse bulleted list items in BOM section
            if inBOMSection {
                if trimmed.isEmpty {
                    continue // Skip blank lines within section
                }
                
                if !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("•") {
                    if trimmed.hasPrefix("## ") { break }
                    continue
                }
                
                let itemText = trimmed
                    .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                if itemText.isEmpty { continue }
                
                partCounter += 1
                let parsed = parseComponentLine(itemText, index: partCounter)
                components.append(parsed)
            }
        }
        
        return components
    }
    
    /// Parses a single component line like "220Ω Resistor — 1/4W carbon film (x2)"
    private func parseComponentLine(_ text: String, index: Int) -> ComponentRequirement {
        // Split on common separators
        let separators = [" — ", " - ", " – ", ": ", " | "]
        var name = text
        var detail = ""
        
        for sep in separators {
            if let range = text.range(of: sep) {
                name = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                detail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        // Extract quantity from patterns like "(x2)", "(qty: 3)", "× 4", "quantity: 2"
        var quantity = 1
        let quantityPatterns = [
            "\\(x(\\d+)\\)",
            "\\(qty:?\\s*(\\d+)\\)",
            "×\\s*(\\d+)",
            "quantity:?\\s*(\\d+)",
            "x(\\d+)$"
        ]
        
        for pattern in quantityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let qtyRange = Range(match.range(at: 1), in: text) {
                quantity = Int(text[qtyRange]) ?? 1
                // Remove quantity text from detail
                if let fullRange = Range(match.range(at: 0), in: text) {
                    detail = detail.replacingOccurrences(of: String(text[fullRange]), with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }
        
        let partId = "part_\(name.lowercased().replacingOccurrences(of: " ", with: "_").prefix(20))"
        
        return ComponentRequirement(
            name: name,
            detail: detail.isEmpty ? name : detail,
            partId: partId,
            quantity: quantity
        )
    }
    
    // MARK: - Steps Extraction
    
    private func extractSteps(from lines: [String]) -> [ProjectStepSummary] {
        let bomHeadings = ["components", "parts", "materials", "bill of materials", "bom", "you will need", "what you need"]
        
        var steps: [ProjectStepSummary] = []
        var currentStepTitle: String?
        var currentInstructionLines: [String] = []
        var currentMistakes: [CommonMistake] = []
        var stepOrder = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect step headings: "## Step 1: Title" or "## 1. Title" or just "## Title"
            if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                let headingText = trimmed
                    .replacingOccurrences(of: "## ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                // Skip BOM sections
                if bomHeadings.contains(where: { headingText.lowercased().contains($0) }) {
                    continue
                }
                
                // Save previous step
                if let title = currentStepTitle {
                    stepOrder += 1
                    steps.append(buildStep(
                        order: stepOrder,
                        title: title,
                        instructions: currentInstructionLines,
                        mistakes: currentMistakes
                    ))
                }
                
                // Parse new step title
                currentStepTitle = cleanStepTitle(headingText)
                currentInstructionLines = []
                currentMistakes = []
                continue
            }
            
            // Collect instruction content under current step
            if currentStepTitle != nil {
                // Detect warning/mistake blocks: "> **Warning**:" or "> ⚠️" or "> Note:"
                if trimmed.hasPrefix("> ") {
                    let warningText = trimmed
                        .replacingOccurrences(of: "> ", with: "")
                        .replacingOccurrences(of: "**Warning**:", with: "")
                        .replacingOccurrences(of: "**Caution**:", with: "")
                        .replacingOccurrences(of: "**Note**:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !warningText.isEmpty {
                        let severity: MistakeSeverity = trimmed.lowercased().contains("caution") ? .critical : .moderate
                        currentMistakes.append(CommonMistake(
                            condition: "User warning",
                            explanation: warningText,
                            severity: severity
                        ))
                    }
                    continue
                }
                
                if !trimmed.isEmpty && !trimmed.hasPrefix("# ") {
                    currentInstructionLines.append(trimmed)
                }
            }
        }
        
        // Save final step
        if let title = currentStepTitle {
            stepOrder += 1
            steps.append(buildStep(
                order: stepOrder,
                title: title,
                instructions: currentInstructionLines,
                mistakes: currentMistakes
            ))
        }
        
        return steps
    }
    
    /// Cleans step title by removing numbering prefixes.
    private func cleanStepTitle(_ raw: String) -> String {
        var cleaned = raw
        
        // Remove "Step N:" prefix
        if let range = cleaned.range(of: "^Step\\s*\\d+\\s*[:.]?\\s*", options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }
        
        // Remove "N." or "N:" prefix
        if let range = cleaned.range(of: "^\\d+\\s*[:.)]\\s*", options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// Builds a `ProjectStepSummary` from extracted components.
    private func buildStep(
        order: Int,
        title: String,
        instructions: [String],
        mistakes: [CommonMistake]
    ) -> ProjectStepSummary {
        let instructionText = instructions.joined(separator: " ")
        let estimatedMinutes = max(1, instructions.count / 2 + 1)
        
        return ProjectStepSummary(
            stepOrder: order,
            title: title,
            instruction: instructionText,
            expectedDurationMinutes: estimatedMinutes,
            commonMistakes: mistakes
        )
    }
    
    // MARK: - Difficulty Inference
    
    private func inferDifficulty(steps: [ProjectStepSummary], components: [ComponentRequirement]) -> Difficulty {
        let totalComplexity = steps.count + components.count
        
        if totalComplexity <= 6 { return .beginner }
        if totalComplexity <= 14 { return .intermediate }
        return .advanced
    }
}
