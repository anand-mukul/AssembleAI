//
//  StateAwareVerificationService.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Concrete verification service implementing the full state-aware verification pipeline.
///
/// Complete Pipeline:
/// ```
/// AssemblyStep → ExpectedAssemblyState
///                      +
/// Captured UIImage → VisionService → VisualObservation
///                      ↓
///             AssemblyStateEstimator
///                      ↓
///            ObservedAssemblyState
///                      ↓
///           AssemblyStateComparator → StateComparison (.correct / .incorrect / .uncertain)
///                      ↓
///              GuidanceGenerator → VerificationResult
/// ```
final class StateAwareVerificationService: VerificationServiceProtocol {
    private let visionService: VisionAnalyzing
    private let estimator: AssemblyStateEstimating
    private let comparator: AssemblyStateComparator
    private let guidanceGenerator: GuidanceGenerating
    private let mockFallbackService: VerificationServiceProtocol
    private let spatialEngine: StateAwareVerificationEngine
    
    var mode: VerificationMode = .hybrid
    
    init(
        visionService: VisionAnalyzing? = nil,
        estimator: AssemblyStateEstimating? = nil,
        comparator: AssemblyStateComparator? = nil,
        guidanceGenerator: GuidanceGenerating? = nil,
        mockFallbackService: VerificationServiceProtocol? = nil,
        spatialEngine: StateAwareVerificationEngine = StateAwareVerificationEngine()
    ) {
        self.visionService = visionService ?? VisionService()
        self.estimator = estimator ?? SpatialAssemblyStateEstimator()
        self.comparator = comparator ?? AssemblyStateComparator()
        self.guidanceGenerator = guidanceGenerator ?? HybridGuidanceGenerator()
        self.mockFallbackService = mockFallbackService ?? MockVerificationService()
        self.spatialEngine = spatialEngine
    }
    
    func verifyStep(_ step: AssemblyStep, image: UIImage?) async throws -> VerificationResult {
        // Mode 1: Mock Mode (deterministic demo flow)
        if mode == .mock {
            return try await mockFallbackService.verifyStep(step, image: image)
        }
        
        // Build explicit expected state for this step
        let expectedState = buildExpectedState(for: step)
        
        // Mode 2 & 3: Vision / Hybrid Pipeline
        guard let image = image else {
            return VerificationResult(
                status: .uncertain,
                confidence: 0.0,
                detectedDescription: "No camera image provided for visual verification.",
                expectedDescription: step.title,
                explanation: "Could not capture a camera frame. Please aim your camera at the assembly and try again."
            )
        }

        // Phase 1: Extract visual observations using Apple Vision
        let observation = try await visionService.analyze(image: image)
        
        // Phase 2: Estimate domain observed state using spatial coordinate inference
        let observedState = try await estimator.estimate(observation: observation)
        
        // Phase 3: Spatial Contract Verification
        var decodedContract: VisualContract? = nil
        if let contractData = step.expectedState.data(using: .utf8) {
            decodedContract = try? JSONDecoder().decode(VisualContract.self, from: contractData)
        }
        
        let spatialOutcome = spatialEngine.verify(
            contract: decodedContract,
            observedState: observedState,
            step: step
        )
        
        // Phase 4: State comparison logic (legacy and invariant checks)
        let comparison = comparator.compare(expected: expectedState, observed: observedState)
        
        // Prioritize spatial contract evaluation if defined
        let status: VerificationStatus
        let explanationText: String
        
        if let contract = decodedContract, (!contract.pinPlacements.isEmpty || !contract.spatialPlacements.isEmpty) {
            status = spatialOutcome.status
            explanationText = spatialOutcome.explanation
        } else {
            switch comparison.status {
            case .correct:
                status = .correct
            case .incorrect:
                status = .incorrect
            case .uncertain:
                status = .uncertain
            }
            
            if let primaryIssue = comparison.issues.first {
                let response = try await guidanceGenerator.generateGuidance(
                    issue: primaryIssue,
                    expectedState: expectedState,
                    observedState: observedState
                )
                explanationText = "\(response.explanation) \(response.action)"
            } else if status == .correct {
                explanationText = "All physical component relationships match the target step contract."
            } else {
                explanationText = "Could not determine placement confidence. Please ensure good lighting and clear camera framing."
            }
        }
        
        let detectedDesc: String
        if observedState.detectedComponents.isEmpty {
            detectedDesc = "No component markings recognized in viewfinder area."
        } else {
            detectedDesc = observedState.detectedComponents.map(\.name).joined(separator: ", ")
        }
        
        let expectedDesc: String
        if expectedState.requiredComponents.isEmpty {
            expectedDesc = step.title
        } else {
            expectedDesc = expectedState.requiredComponents.map(\.name).joined(separator: ", ")
        }
        
        return VerificationResult(
            status: status,
            confidence: max(comparison.confidence, spatialOutcome.confidence),
            detectedDescription: detectedDesc,
            expectedDescription: expectedDesc,
            explanation: explanationText
        )
    }
    
    // MARK: - Expected State Factory
    
    private func buildExpectedState(for step: AssemblyStep) -> ExpectedAssemblyState {
        ExpectedAssemblyState.forStep(step)
    }
}
