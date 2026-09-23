//
//  MockMultimodalVisionVerifier.swift
//  AssembleAITests
//
//  Deterministic mock for MultimodalVisionVerifier.
//  Enables full Simulator test coverage without requiring
//  on-device FoundationModels inference (iPhone 16 Pro / iOS 26+).
//

import Foundation
import CoreVideo
@testable import AssembleAI

/// Scriptable mock actor for MultimodalVisionVerifier used in unit/integration tests.
/// Conforms to `MultimodalVisionVerifying` protocol so it can be injected anywhere.
actor MockMultimodalVisionVerifier: MultimodalVisionVerifying {

    // MARK: - Scripted State

    /// Queue of assessments to return in order. If empty, returns `defaultAssessment`.
    private var scriptedAssessments: [MultimodalAssemblyAssessment] = []
    private var callCount: Int = 0
    private(set) var verifyCallCount: Int = 0
    private(set) var resetCallCount: Int = 0

    /// Fallback assessment returned when `scriptedAssessments` is exhausted.
    var defaultAssessment: MultimodalAssemblyAssessment = MultimodalAssemblyAssessment(
        isStepComplete: true,
        detectedComponents: [
            MultimodalDetectedPart(
                partName: "220Ω Resistor",
                category: "Resistor",
                colorBandsOrMarkings: ["red", "red", "brown"],
                observedLocation: "Row 10-15",
                confidence: 0.92
            )
        ],
        alignmentStatus: "Nominal",
        identifiedMistakes: [],
        suggestedCorrection: nil,
        confidenceScore: 0.92,
        executionLatencyMs: 5.0,
        isMultimodalEngineActive: false
    )

    // MARK: - Configuration

    func setScriptedAssessments(_ assessments: [MultimodalAssemblyAssessment]) {
        scriptedAssessments = assessments
        callCount = 0
    }

    // MARK: - MultimodalVisionVerifying

    func verify(
        frame: CVPixelBuffer,
        step: AssemblyStep,
        domain: AssemblyDomain
    ) async -> MultimodalAssemblyAssessment {
        verifyCallCount += 1
        if !scriptedAssessments.isEmpty {
            let index = min(callCount, scriptedAssessments.count - 1)
            callCount += 1
            return scriptedAssessments[index]
        }
        return defaultAssessment
    }

    func resetSession() async {
        resetCallCount += 1
        scriptedAssessments = []
        callCount = 0
    }
}
