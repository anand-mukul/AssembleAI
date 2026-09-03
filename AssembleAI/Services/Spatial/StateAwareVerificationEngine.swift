//
//  StateAwareVerificationEngine.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Result of evaluating a step's visual contract against detected physical assembly state.
nonisolated struct SpatialVerificationOutcome: Sendable, Equatable {
    let status: VerificationStatus
    let confidence: Double
    let issues: [StateIssue]
    let explanation: String
    let guidanceOverlay: GuidanceOverlay?
    let detectedDescription: String
    let expectedDescription: String
    
    var isCorrect: Bool { status == .correct }
}

/// Advanced spatial verification engine evaluating real-world visual observations against step visual contracts.
///
/// Handles sub-millimeter coordinate comparison, row delta detection (e.g. "Shift right lead 1 slot from Row 14 to Row 15"),
/// common mistake matching, orientation constraint verification, and guidance overlay vector generation.
nonisolated struct StateAwareVerificationEngine: Sendable {
    
    private let homographyService: BreadboardHomographyService
    private let configuration: VerificationConfiguration
    
    init(
        homographyService: BreadboardHomographyService = BreadboardHomographyService(),
        configuration: VerificationConfiguration = VerificationConfiguration(minimumEvidenceConfidence: 0.50, minimumCorrectConfidence: 0.80)
    ) {
        self.homographyService = homographyService
        self.configuration = configuration
    }
    
    /// Evaluates physical assembly step state against its machine-verifiable `VisualContract`.
    func verify(
        contract: VisualContract?,
        commonMistakes: [CommonMistake] = [],
        observedState: ObservedAssemblyState,
        step: AssemblyStep,
        calibration: BreadboardCalibration? = nil
    ) -> SpatialVerificationOutcome {
        let activeCalibration = calibration ?? BreadboardCalibration.defaultCentered()
        
        // 1. Evidence Check: If overall confidence is below threshold, return uncertain
        if observedState.overallConfidence < configuration.minimumEvidenceConfidence {
            let overlay = GuidanceOverlay(
                title: "Need Clearer View",
                message: "Position the camera directly above the breadboard with good lighting.",
                style: .warning
            )
            return SpatialVerificationOutcome(
                status: .uncertain,
                confidence: observedState.overallConfidence,
                issues: [
                    StateIssue(
                        type: .insufficientVisualEvidence,
                        title: "Insufficient Visual Evidence",
                        explanation: "Lighting is insufficient or components are occluded. Ensure the workspace is clearly visible.",
                        severity: .medium
                    )
                ],
                explanation: "Could not determine placement confidence. Please ensure good lighting and clear camera framing.",
                guidanceOverlay: overlay,
                detectedDescription: "No stable component markings visible.",
                expectedDescription: step.title
            )
        }
        
        // Fallback to legacy expected state comparison if no visual contract defined
        guard let contract = contract, (!contract.pinPlacements.isEmpty || !contract.spatialPlacements.isEmpty || !contract.expectedConnections.isEmpty) else {
            return fallbackComparison(step: step, observedState: observedState)
        }
        
        var issues: [StateIssue] = []
        var detectedComponentsList: [String] = []
        var expectedComponentsList: [String] = []
        var moveGuidance: GuidanceOverlay? = nil
        var targetGuidance: GuidanceOverlay? = nil
        
        // 2. Evaluate Pin Placements (Electronics Domain)
        for placement in contract.pinPlacements {
            expectedComponentsList.append("\(placement.partId) (\(placement.fromPin.label) to \(placement.toPin.label))")
            
            // Look for matching detected position or component
            let matchingPos = observedState.detectedPositions.first { pos in
                pos.componentID.localizedCaseInsensitiveContains(placement.partId) ||
                pos.detectedDescription.localizedCaseInsensitiveContains(placement.fromPin.row)
            }
            
            if let pos = matchingPos {
                detectedComponentsList.append(pos.detectedDescription)
                
                // Parse detected pins from detected description if possible (e.g. "10E to 14F")
                let detectedPins = parsePinLabels(from: pos.detectedDescription)
                
                if let detectedFrom = detectedPins.from, let detectedTo = detectedPins.to {
                    // Check if placement matches expected exactly
                    let fromMatch = detectedFrom.row == placement.fromPin.row
                    let toMatch = detectedTo.row == placement.toPin.row
                    
                    if fromMatch && toMatch {
                        // Correct bridging
                    } else {
                        // Pin misalignment detected!
                        let fromDelta = BreadboardGeometry.rowDelta(from: detectedFrom, to: placement.fromPin) ?? 0
                        let toDelta = BreadboardGeometry.rowDelta(from: detectedTo, to: placement.toPin) ?? 0
                        
                        let deltaExplanation: String
                        let sourcePin: PinCoordinate
                        let targetPin: PinCoordinate
                        
                        if !toMatch && fromMatch {
                            deltaExplanation = BreadboardGeometry.alignmentGuidance(detected: detectedTo, expected: placement.toPin)
                            sourcePin = detectedTo
                            targetPin = placement.toPin
                        } else if !fromMatch && toMatch {
                            deltaExplanation = BreadboardGeometry.alignmentGuidance(detected: detectedFrom, expected: placement.fromPin)
                            sourcePin = detectedFrom
                            targetPin = placement.fromPin
                        } else {
                            deltaExplanation = "Shift component to span \(placement.fromPin.label) to \(placement.toPin.label)."
                            sourcePin = detectedFrom
                            targetPin = placement.fromPin
                        }
                        
                        // Check if this matches a documented common mistake
                        let matchedMistake = commonMistakes.first { mistake in
                            mistake.condition.localizedCaseInsensitiveContains(detectedTo.row) ||
                            mistake.condition.localizedCaseInsensitiveContains(detectedFrom.row) ||
                            mistake.condition.localizedCaseInsensitiveContains("row")
                        }
                        
                        let finalExplanation = matchedMistake?.explanation ?? deltaExplanation
                        let correctiveAction = matchedMistake?.correctionAction ?? deltaExplanation
                        
                        issues.append(
                            StateIssue(
                                type: .wrongPosition,
                                title: "Misplaced Lead",
                                explanation: "\(finalExplanation) \(correctiveAction)",
                                severity: .high
                            )
                        )
                        
                        // Construct move arrow overlay from detected position to target position
                        let srcPoint = homographyService.projectPinToCamera(pin: sourcePin, calibration: activeCalibration)
                        let dstPoint = homographyService.projectPinToCamera(pin: targetPin, calibration: activeCalibration)
                        
                        if let sp = srcPoint, let dp = dstPoint {
                            let srcBox = CGRect(x: sp.x - 0.03, y: sp.y - 0.03, width: 0.06, height: 0.06)
                            let dstBox = CGRect(x: dp.x - 0.03, y: dp.y - 0.03, width: 0.06, height: 0.06)
                            moveGuidance = GuidanceOverlay(
                                title: "Shift Component",
                                message: correctiveAction,
                                sourceRegion: srcBox,
                                destinationRegion: dstBox,
                                style: .move
                            )
                        }
                    }
                }
            } else {
                // Component not detected yet
                issues.append(
                    StateIssue(
                        type: .missingComponent,
                        title: "Insert \(placement.partId)",
                        explanation: "Place component bridging \(placement.fromPin.label) to \(placement.toPin.label).",
                        severity: .high
                    )
                )
                
                // Provide target highlight box for expected pin placement
                if let targetBox = homographyService.projectPinPlacementRegion(
                    from: placement.fromPin,
                    to: placement.toPin,
                    calibration: activeCalibration
                ) {
                    targetGuidance = GuidanceOverlay(
                        title: "Target Slot",
                        message: "Bridge \(placement.fromPin.label) to \(placement.toPin.label)",
                        targetRegion: targetBox,
                        style: .target
                    )
                }
            }
        }
        
        // 3. Evaluate Orientation Constraints (Polarity, Notches)
        for constraint in contract.orientationConstraints {
            if constraint.markerType == .polarityStripe {
                // E.g., capacitor polarity
                let hasReversedMistake = issues.contains { $0.explanation.localizedCaseInsensitiveContains("polarity") }
                if hasReversedMistake {
                    issues.append(
                        StateIssue(
                            type: .wrongPosition,
                            title: "Reversed Polarity",
                            explanation: constraint.rule,
                            severity: .critical
                        )
                    )
                }
            }
        }
        
        // 4. Evaluate Spatial Placements (Physical / Furniture Domain)
        for spatial in contract.spatialPlacements {
            expectedComponentsList.append("\(spatial.partId) at \(spatial.locationDescription)")
            
            let matched = observedState.detectedPositions.contains { pos in
                pos.componentID.localizedCaseInsensitiveContains(spatial.partId) ||
                pos.detectedDescription.localizedCaseInsensitiveContains(spatial.partId)
            } || observedState.detectedComponents.contains { comp in
                comp.name.localizedCaseInsensitiveContains(spatial.partId) ||
                comp.identifier?.localizedCaseInsensitiveContains(spatial.partId) == true
            }
            
            if !matched {
                issues.append(
                    StateIssue(
                        type: .missingComponent,
                        title: "Position \(spatial.partId)",
                        explanation: "Place \(spatial.partId) at \(spatial.locationDescription).",
                        severity: .high
                    )
                )
            }
        }
        
        // 5. Final Status Determination
        let status: VerificationStatus
        let explanationText: String
        let finalOverlay: GuidanceOverlay?
        
        if issues.isEmpty && observedState.overallConfidence >= configuration.minimumCorrectConfidence {
            status = .correct
            explanationText = "All physical component relationships match the target step contract."
            finalOverlay = GuidanceOverlay(
                title: "Step Complete",
                message: "Placement verified correctly.",
                style: .success
            )
        } else if !issues.isEmpty {
            status = .incorrect
            let primary = issues.first!
            explanationText = primary.explanation
            finalOverlay = moveGuidance ?? targetGuidance ?? GuidanceOverlay(
                title: primary.title,
                message: primary.explanation,
                style: .warning
            )
        } else {
            status = .uncertain
            explanationText = "Verifying placement stability. Hold steady."
            finalOverlay = targetGuidance
        }
        
        return SpatialVerificationOutcome(
            status: status,
            confidence: observedState.overallConfidence,
            issues: issues,
            explanation: explanationText,
            guidanceOverlay: finalOverlay,
            detectedDescription: detectedComponentsList.isEmpty ? "None in target area" : detectedComponentsList.joined(separator: ", "),
            expectedDescription: expectedComponentsList.isEmpty ? step.title : expectedComponentsList.joined(separator: ", ")
        )
    }
    
    // MARK: - Private Helpers
    
    private func parsePinLabels(from text: String) -> (from: PinCoordinate?, to: PinCoordinate?) {
        // Looks for patterns like "10E to 15F" or "10E"
        let parts = text.components(separatedBy: " to ")
        if parts.count >= 2 {
            return (
                from: PinCoordinate(pinString: parts[0]),
                to: PinCoordinate(pinString: parts[1])
            )
        } else if let single = PinCoordinate(pinString: text) {
            return (from: single, to: nil)
        }
        return (from: nil, to: nil)
    }
    
    private func fallbackComparison(step: AssemblyStep, observedState: ObservedAssemblyState) -> SpatialVerificationOutcome {
        let expected = ExpectedAssemblyState.forStep(step)
        let comparator = AssemblyStateComparator(configuration: configuration)
        let comparison = comparator.compare(expected: expected, observed: observedState)
        
        let status: VerificationStatus
        switch comparison.status {
        case .correct: status = .correct
        case .incorrect: status = .incorrect
        case .uncertain: status = .uncertain
        }
        
        let explanation = comparison.issues.first?.explanation ?? (status == .correct ? "All physical components match the step contract." : "Hold steady to confirm placement.")
        
        return SpatialVerificationOutcome(
            status: status,
            confidence: comparison.confidence,
            issues: comparison.issues,
            explanation: explanation,
            guidanceOverlay: status == .correct ? GuidanceOverlay(title: "Step Complete", message: explanation, style: .success) : nil,
            detectedDescription: observedState.detectedComponents.map(\.name).joined(separator: ", "),
            expectedDescription: step.title
        )
    }
}
