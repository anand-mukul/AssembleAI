//
//  SpatialVerificationEngineTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class SpatialVerificationEngineTests: XCTestCase {
    
    private var engine: StateAwareVerificationEngine!
    
    override func setUp() {
        super.setUp()
        engine = StateAwareVerificationEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Exact Pin Placement Verification (Success)
    
    func testExactPinPlacementVerification() {
        let contract = VisualContract(
            requiredComponentIds: ["part_res_220"],
            pinPlacements: [
                PinPlacement(
                    partId: "part_res_220",
                    fromPin: PinCoordinate(row: "10", column: "E"),
                    toPin: PinCoordinate(row: "15", column: "F")
                )
            ]
        )
        
        let step = AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place resistor bridging Row 10 to Row 15."
        )
        
        // Observed component at exact target coordinates
        let observed = ObservedAssemblyState(
            detectedComponents: [
                ObservedComponent(identifier: "part_res_220", name: "220Ω Resistor", confidence: 0.95)
            ],
            detectedPositions: [
                ObservedPosition(
                    componentID: "part_res_220",
                    detectedDescription: "10E to 15F",
                    region: CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2),
                    confidence: 0.95
                )
            ],
            overallConfidence: 0.92
        )
        
        let outcome = engine.verify(contract: contract, observedState: observed, step: step)
        
        XCTAssertEqual(outcome.status, .correct)
        XCTAssertTrue(outcome.issues.isEmpty)
        XCTAssertEqual(outcome.guidanceOverlay?.style, .success)
    }
    
    // MARK: - Test 2: Misplaced Lead Detection with Row Delta & Move Guidance
    
    func testMisplacedLeadDetectionGeneratesMoveGuidance() {
        let contract = VisualContract(
            requiredComponentIds: ["part_res_220"],
            pinPlacements: [
                PinPlacement(
                    partId: "part_res_220",
                    fromPin: PinCoordinate(row: "10", column: "E"),
                    toPin: PinCoordinate(row: "15", column: "F")
                )
            ]
        )
        
        let commonMistakes = [
            CommonMistake(
                condition: "Row 14 bridging",
                explanation: "The right lead is inserted into Row 14 instead of Row 15.",
                correctionAction: "Shift the right lead one slot down from Row 14 to Row 15.",
                severity: .moderate
            )
        ]
        
        let step = AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place resistor bridging Row 10 to Row 15."
        )
        
        // User inserted into Row 14 instead of Row 15!
        let observed = ObservedAssemblyState(
            detectedComponents: [
                ObservedComponent(identifier: "part_res_220", name: "220Ω Resistor", confidence: 0.90)
            ],
            detectedPositions: [
                ObservedPosition(
                    componentID: "part_res_220",
                    detectedDescription: "10E to 14F",
                    region: CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2),
                    confidence: 0.90
                )
            ],
            overallConfidence: 0.88
        )
        
        let outcome = engine.verify(
            contract: contract,
            commonMistakes: commonMistakes,
            observedState: observed,
            step: step
        )
        
        XCTAssertEqual(outcome.status, .incorrect)
        XCTAssertFalse(outcome.issues.isEmpty)
        
        // Should detect wrong position issue
        let issue = outcome.issues.first
        XCTAssertEqual(issue?.type, .wrongPosition)
        XCTAssertTrue(outcome.explanation.contains("Row 14") || outcome.explanation.contains("Row 15"))
        
        // Should generate .move guidance with source and destination coordinates
        XCTAssertEqual(outcome.guidanceOverlay?.style, .move)
        XCTAssertNotNil(outcome.guidanceOverlay?.sourceRegion)
        XCTAssertNotNil(outcome.guidanceOverlay?.destinationRegion)
    }
    
    // MARK: - Test 3: Missing Component Highlights Target Region
    
    func testMissingComponentGeneratesTargetHighlight() {
        let contract = VisualContract(
            requiredComponentIds: ["part_res_220"],
            pinPlacements: [
                PinPlacement(
                    partId: "part_res_220",
                    fromPin: PinCoordinate(row: "10", column: "E"),
                    toPin: PinCoordinate(row: "15", column: "F")
                )
            ]
        )
        
        let step = AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Insert Resistor",
            instruction: "Place resistor."
        )
        
        // Nothing detected yet
        let observed = ObservedAssemblyState(
            detectedComponents: [],
            detectedPositions: [],
            overallConfidence: 0.70
        )
        
        let outcome = engine.verify(contract: contract, observedState: observed, step: step)
        
        XCTAssertEqual(outcome.status, .incorrect)
        XCTAssertEqual(outcome.issues.first?.type, .missingComponent)
        XCTAssertEqual(outcome.guidanceOverlay?.style, .target)
        XCTAssertNotNil(outcome.guidanceOverlay?.targetRegion)
    }
    
    // MARK: - Test 4: Insufficient Evidence Returns Uncertain
    
    func testInsufficientEvidenceReturnsUncertain() {
        let contract = VisualContract(
            requiredComponentIds: ["part_res_220"],
            pinPlacements: [
                PinPlacement(
                    partId: "part_res_220",
                    fromPin: PinCoordinate(row: "10", column: "E"),
                    toPin: PinCoordinate(row: "15", column: "F")
                )
            ]
        )
        
        let step = AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Step", instruction: "Do.")
        
        // Extremely low confidence (e.g. blocked camera or dark bench)
        let observed = ObservedAssemblyState(
            detectedComponents: [],
            overallConfidence: 0.25
        )
        
        let outcome = engine.verify(contract: contract, observedState: observed, step: step)
        
        XCTAssertEqual(outcome.status, .uncertain)
        XCTAssertEqual(outcome.guidanceOverlay?.style, .warning)
    }
    
    // MARK: - Test 5: WireContinuityTracer Evaluation
    
    func testWireContinuityTracerValidConnection() {
        let wire = TracedWire(
            color: .black,
            fromPin: PinCoordinate(row: "12", column: "B"),
            toPin: PinCoordinate(row: "GND", column: "-")
        )
        
        let eval = WireContinuityTracer.evaluateConnection(
            expectedFrom: "12B",
            expectedTo: "GND",
            tracedWires: [wire]
        )
        
        XCTAssertTrue(eval.isConnected)
        XCTAssertFalse(eval.isReversedPolarity)
        XCTAssertFalse(eval.isSelfShort)
    }
    
    func testWireContinuityTracerReversedPolarity() {
        // Black wire connected to positive (+) rail instead of ground
        let wire = TracedWire(
            color: .black,
            fromPin: PinCoordinate(row: "12", column: "B"),
            toPin: PinCoordinate(row: "VCC", column: "+")
        )
        
        let eval = WireContinuityTracer.evaluateConnection(
            expectedFrom: "12B",
            expectedTo: "GND",
            tracedWires: [wire]
        )
        
        XCTAssertFalse(eval.isConnected)
        XCTAssertTrue(eval.isReversedPolarity)
        XCTAssertTrue(eval.explanation.contains("VCC"))
    }
    
    func testWireContinuityTracerSelfShort() {
        // Both ends in row 14 on left bank (A and C)
        let wire = TracedWire(
            color: .red,
            fromPin: PinCoordinate(row: "14", column: "A"),
            toPin: PinCoordinate(row: "14", column: "C")
        )
        
        XCTAssertTrue(wire.isSelfShort)
        
        let eval = WireContinuityTracer.evaluateConnection(
            expectedFrom: "14A",
            expectedTo: "14C",
            tracedWires: [wire]
        )
        
        XCTAssertTrue(eval.isSelfShort)
        XCTAssertTrue(eval.explanation.contains("short circuit"))
    }
    
    // MARK: - Test 6: SpatialAssemblyStateEstimator Integration
    
    func testSpatialAssemblyStateEstimatorProducesPinPositions() async throws {
        let estimator = SpatialAssemblyStateEstimator()
        
        let observation = VisualObservation(
            imageSize: CGSize(width: 1920, height: 1080),
            detectedText: [
                DetectedText(text: "220", confidence: 0.92, boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.1)),
                DetectedText(text: "GND", confidence: 0.88, boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.1, height: 0.1))
            ],
            regions: [
                DetectedRegion(label: "Resistor Body", confidence: 0.90, boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.1))
            ],
            processingTimeMs: 12.0
        )
        
        let state = try await estimator.estimate(observation: observation)
        
        XCTAssertGreaterThan(state.detectedComponents.count, 0)
        XCTAssertGreaterThan(state.detectedPositions.count, 0)
        XCTAssertGreaterThan(state.detectedConnections.count, 0)
        XCTAssertGreaterThan(state.overallConfidence, 0.60)
    }
}
