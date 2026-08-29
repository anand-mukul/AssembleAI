//
//  FoundationModelsGuidanceEngine.swift
//  AssembleAI
//

import Foundation
import FoundationModels

/// On-device guidance engine powered by Apple Foundation Models framework.
///
/// Generates natural-language explanations, interprets assembly instructions,
/// and produces adaptive troubleshooting steps when errors are detected.
///
/// This engine does NOT make verification decisions — it only provides
/// human-readable guidance based on deterministic results from the verification engine.
@available(iOS 26.0, *)
actor FoundationModelsGuidanceEngine {
    
    /// Generates a natural-language explanation for a verification result using the on-device Foundation Model.
    func generateExplanation(
        step: AssemblyStep,
        deterministicResult: DeterministicResult
    ) async -> String {
        let prompt = buildExplanationPrompt(step: step, result: deterministicResult)
        
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let explanation = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return explanation.isEmpty ? fallbackExplanation(result: deterministicResult) : explanation
        } catch {
            // Graceful fallback if Foundation Models are unavailable on this device
            return fallbackExplanation(result: deterministicResult)
        }
    }
    
    /// Generates adaptive remediation guidance when a step fails verification.
    func generateRemediationGuidance(
        step: AssemblyStep,
        deterministicResult: DeterministicResult
    ) async -> String? {
        guard deterministicResult.status == .incorrect else { return nil }
        
        let prompt = buildRemediationPrompt(step: step, result: deterministicResult)
        
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let guidance = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return guidance.isEmpty ? nil : guidance
        } catch {
            return nil
        }
    }
    
    // MARK: - Prompt Construction
    
    private func buildExplanationPrompt(step: AssemblyStep, result: DeterministicResult) -> String {
        let statusText = result.status == .correct ? "PASSED" : "FAILED"
        let matchedText = result.matchedMarkers.isEmpty ? "none" : result.matchedMarkers.joined(separator: ", ")
        let missingText = result.missingMarkers.isEmpty ? "none" : result.missingMarkers.joined(separator: ", ")
        
        return """
        You are an expert electronics assembly assistant. Explain a visual verification result to a user in 2-3 concise sentences.
        
        Assembly Step: "\(step.title)"
        Instruction: "\(step.instruction)"
        Verification Status: \(statusText)
        Confidence: \(Int(result.confidence * 100))%
        Detected: \(result.detectedDescription)
        Matched Markers: \(matchedText)
        Missing Markers: \(missingText)
        
        Provide a clear, helpful explanation of what was observed and whether the step appears complete.
        """
    }
    
    private func buildRemediationPrompt(step: AssemblyStep, result: DeterministicResult) -> String {
        let missingText = result.missingMarkers.isEmpty ? "unknown components" : result.missingMarkers.joined(separator: ", ")
        
        return """
        You are an expert electronics assembly assistant. The user's assembly step has failed verification.
        
        Failed Step: "\(step.title)"
        Instruction: "\(step.instruction)"
        Detected State: \(result.detectedDescription)
        Missing Components: \(missingText)
        
        Provide 2-3 specific, actionable troubleshooting steps the user should take to correct this issue. Be concise and practical.
        """
    }
    
    // MARK: - Fallback (No Foundation Models Available)
    
    /// Generates a deterministic fallback explanation when Foundation Models are unavailable.
    private func fallbackExplanation(result: DeterministicResult) -> String {
        if result.status == .correct {
            if result.matchedMarkers.isEmpty {
                return "Physical components detected in the workspace. The assembly step appears consistent with expectations based on spatial analysis."
            } else {
                return "Component markers (\(result.matchedMarkers.joined(separator: ", "))) were identified. The assembly step matches the expected configuration."
            }
        } else {
            if result.missingMarkers.isEmpty {
                return "No physical components were clearly detected in the camera frame. Ensure the assembly area is within the viewfinder reticle."
            } else {
                return "Expected markers (\(result.missingMarkers.joined(separator: ", "))) were not found. Verify the component is properly seated and the markings face the camera."
            }
        }
    }
}

// MARK: - Pre-iOS 26 Fallback

/// Fallback guidance engine for devices that do not support Foundation Models.
/// Uses deterministic template-based explanations.
struct FallbackGuidanceEngine: Sendable {
    
    func generateExplanation(step: AssemblyStep, deterministicResult: DeterministicResult) -> String {
        if deterministicResult.status == .correct {
            if deterministicResult.matchedMarkers.isEmpty {
                return "Physical components detected in the workspace. The assembly step appears consistent with expectations based on spatial analysis."
            } else {
                return "Component markers (\(deterministicResult.matchedMarkers.joined(separator: ", "))) were identified. The assembly step matches the expected configuration."
            }
        } else {
            if deterministicResult.missingMarkers.isEmpty {
                return "No physical components were clearly detected in the camera frame. Ensure the assembly area is within the viewfinder reticle."
            } else {
                return "Expected markers (\(deterministicResult.missingMarkers.joined(separator: ", "))) were not found. Verify the component is properly seated and the markings face the camera."
            }
        }
    }
}
