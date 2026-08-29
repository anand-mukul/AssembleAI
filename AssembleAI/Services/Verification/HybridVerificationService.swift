//
//  HybridVerificationService.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Unified hybrid verification service combining deterministic Vision analysis with Foundation Models guidance.
///
/// Pipeline Architecture:
/// ```
/// Camera Image (UIImage)
///   → VisionObservationService (Apple Vision: OCR + Rectangle Detection)
///   → DeterministicVerificationEngine (Rule-based pass/fail)
///   → FoundationModelsGuidanceEngine (Natural-language explanation & remediation)
///   → VerificationResult
/// ```
///
/// The language model is NEVER used for pass/fail decisions.
/// Verification status and confidence are computed deterministically.
/// Foundation Models are used ONLY for generating human-readable explanations.
final class HybridVerificationService: VerificationServiceProtocol {
    private let visionService = VisionObservationService()
    private let deterministicEngine = DeterministicVerificationEngine()
    private let fallbackGuidance = FallbackGuidanceEngine()
    
    func verifyStep(_ step: AssemblyStep, image: UIImage?) async throws -> VerificationResult {
        // Phase 1: Run Apple Vision analysis on the captured frame
        let observations: VisionObservations
        if let image = image {
            observations = try await visionService.analyze(image: image)
        } else {
            // No image provided — treat as empty frame
            observations = VisionObservations(recognizedTexts: [], detectedRectangles: [])
        }
        
        // Phase 2: Deterministic verification (pass/fail + confidence)
        let deterministicResult = deterministicEngine.evaluate(step: step, observations: observations)
        
        // Phase 3: Generate natural-language explanation using Foundation Models
        let explanation: String
        if #available(iOS 26.0, *) {
            let guidanceEngine = FoundationModelsGuidanceEngine()
            let llmExplanation = await guidanceEngine.generateExplanation(
                step: step,
                deterministicResult: deterministicResult
            )
            
            // Append remediation guidance if step failed
            if deterministicResult.status == .incorrect {
                let remediation = await guidanceEngine.generateRemediationGuidance(
                    step: step,
                    deterministicResult: deterministicResult
                )
                if let remediation = remediation {
                    explanation = "\(llmExplanation)\n\n\(remediation)"
                } else {
                    explanation = llmExplanation
                }
            } else {
                explanation = llmExplanation
            }
        } else {
            // Pre-iOS 26: use deterministic template explanations
            explanation = fallbackGuidance.generateExplanation(
                step: step,
                deterministicResult: deterministicResult
            )
        }
        
        return VerificationResult(
            status: deterministicResult.status,
            confidence: deterministicResult.confidence,
            detectedDescription: deterministicResult.detectedDescription,
            expectedDescription: deterministicResult.expectedDescription,
            explanation: explanation
        )
    }
}
