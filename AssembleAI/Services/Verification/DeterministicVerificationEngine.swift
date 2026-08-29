//
//  DeterministicVerificationEngine.swift
//  AssembleAI
//

import Foundation

/// Structured intermediate result from deterministic rule-based verification.
struct DeterministicResult: Sendable {
    let status: VerificationStatus
    let confidence: Double
    let detectedDescription: String
    let expectedDescription: String
    let matchedMarkers: [String]
    let missingMarkers: [String]
}

/// Rule-based verification engine that evaluates Vision observations against assembly step specifications.
///
/// This engine performs **deterministic pass/fail** checks using:
/// - OCR text marker matching (component values like "10K", "100uF", "ATmega328P")
/// - Spatial rectangle count heuristics (expected component count vs detected)
/// - Step-specific expected marker extraction from `AssemblyStep.expectedState`
///
/// The language model is NOT used for verification decisions.
struct DeterministicVerificationEngine: Sendable {
    
    /// Evaluates Vision observations against the assembly step contract.
    func evaluate(step: AssemblyStep, observations: VisionObservations) -> DeterministicResult {
        let expectedMarkers = extractExpectedMarkers(from: step)
        
        // If no expected markers are defined, use heuristic analysis
        if expectedMarkers.isEmpty {
            return evaluateHeuristic(step: step, observations: observations)
        }
        
        // Deterministic marker matching
        var matchedMarkers: [String] = []
        var missingMarkers: [String] = []
        
        for marker in expectedMarkers {
            if observations.containsText(marker) {
                matchedMarkers.append(marker)
            } else {
                missingMarkers.append(marker)
            }
        }
        
        let matchRatio = expectedMarkers.isEmpty ? 0.0 : Double(matchedMarkers.count) / Double(expectedMarkers.count)
        
        // Rectangle presence bonus: components physically present
        let hasPhysicalPresence = observations.rectangleCount >= 1
        let presenceBonus: Double = hasPhysicalPresence ? 0.1 : 0.0
        
        let confidence = min(1.0, matchRatio * 0.85 + presenceBonus + (observations.hasText ? 0.05 : 0.0))
        let isCorrect = matchRatio >= 0.5 && hasPhysicalPresence
        
        let detectedDesc: String
        if matchedMarkers.isEmpty && !observations.hasText {
            detectedDesc = "No component markings or physical objects detected in frame"
        } else if matchedMarkers.isEmpty {
            detectedDesc = "Detected text: \(observations.recognizedTexts.prefix(5).joined(separator: ", ")). No expected markers found."
        } else {
            detectedDesc = "Matched markers: \(matchedMarkers.joined(separator: ", ")). \(observations.rectangleCount) component(s) detected."
        }
        
        let expectedDesc = "\(step.title) — Expected markers: \(expectedMarkers.joined(separator: ", "))"
        
        return DeterministicResult(
            status: isCorrect ? .correct : .incorrect,
            confidence: confidence,
            detectedDescription: detectedDesc,
            expectedDescription: expectedDesc,
            matchedMarkers: matchedMarkers,
            missingMarkers: missingMarkers
        )
    }
    
    // MARK: - Heuristic Analysis (No Explicit Markers)
    
    /// Fallback evaluation when no explicit markers are defined in expectedState.
    /// Uses rectangle count and text presence as proxy signals.
    private func evaluateHeuristic(step: AssemblyStep, observations: VisionObservations) -> DeterministicResult {
        let hasComponents = observations.rectangleCount >= 1
        let hasRelevantText = observations.hasText
        
        let confidence: Double
        let status: VerificationStatus
        
        if hasComponents && hasRelevantText {
            confidence = 0.78
            status = .correct
        } else if hasComponents {
            confidence = 0.60
            status = .correct
        } else {
            confidence = 0.35
            status = .incorrect
        }
        
        let detectedDesc: String
        if hasComponents {
            let textSummary = hasRelevantText ? " Recognized: \(observations.recognizedTexts.prefix(3).joined(separator: ", "))." : ""
            detectedDesc = "\(observations.rectangleCount) component(s) detected in workspace.\(textSummary)"
        } else {
            detectedDesc = "No physical components detected in the camera frame."
        }
        
        return DeterministicResult(
            status: status,
            confidence: confidence,
            detectedDescription: detectedDesc,
            expectedDescription: step.title,
            matchedMarkers: [],
            missingMarkers: []
        )
    }
    
    // MARK: - Marker Extraction
    
    /// Extracts expected component markers from the step's `expectedState` JSON or falls back to parsing the step title.
    private func extractExpectedMarkers(from step: AssemblyStep) -> [String] {
        // Attempt JSON parsing of expectedState
        if let data = step.expectedState.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let markers = json["markers"] as? [String], !markers.isEmpty {
            return markers
        }
        
        // Fallback: Extract common component values from the step title/instruction
        let combinedText = "\(step.title) \(step.instruction)"
        var extracted: [String] = []
        
        // Common electronic component value patterns
        let patterns = [
            "10K", "100K", "1K", "4.7K", "220", "470",
            "100uF", "10uF", "22uF", "47uF", "1uF", "0.1uF",
            "ATmega328P", "ATmega", "ESP32", "STM32",
            "LED", "RGB", "USB", "UART", "SPI", "I2C"
        ]
        
        for pattern in patterns {
            if combinedText.localizedCaseInsensitiveContains(pattern) {
                extracted.append(pattern)
            }
        }
        
        return extracted
    }
}
