//
//  StateComparatorTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class StateComparatorTests: XCTestCase {
    
    private var comparator: AssemblyStateComparator!
    
    override func setUp() {
        super.setUp()
        comparator = AssemblyStateComparator(
            configuration: VerificationConfiguration(
                minimumEvidenceConfidence: 0.50,
                minimumCorrectConfidence: 0.75
            )
        )
    }
    
    override func tearDown() {
        comparator = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Correct State Comparison
    func testCorrectStateComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "resistor_220", name: "220Ω Resistor")]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "resistor_220", name: "220Ω Resistor", confidence: 0.94)],
            overallConfidence: 0.92
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .correct)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.matchedComponents.count, 1)
    }
    
    // MARK: - Test 2: Wrong Position Comparison
    func testWrongPositionComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "resistor_220", name: "220Ω Resistor")],
            requiredConnections: [ExpectedConnection(from: "GND Rail", to: "Pin Header")]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "resistor_220", name: "220Ω Resistor", confidence: 0.90)],
            detectedConnections: [ObservedConnection(from: "5V Rail", to: "Pin Header", confidence: 0.85)],
            overallConfidence: 0.88
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .incorrect)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.issues.contains { $0.type == .wrongConnection })
    }
    
    // MARK: - Test 3: Missing Component Comparison
    func testMissingComponentComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 3,
            requiredComponents: [ExpectedComponent(identifier: "led_red", name: "Red LED")]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [],
            overallConfidence: 0.60
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .incorrect)
        XCTAssertTrue(result.issues.contains { $0.type == .missingComponent })
    }
    
    // MARK: - Test 4: Uncertain Comparison (Insufficient Evidence)
    func testUncertainComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "resistor_220", name: "220Ω Resistor")]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [],
            overallConfidence: 0.42 // Below minimumEvidenceConfidence 0.50
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .uncertain)
        XCTAssertTrue(result.issues.contains { $0.type == .insufficientVisualEvidence })
    }
    
    // MARK: - Test 5: Unexpected Component Comparison
    func testUnexpectedComponentComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "resistor_220", name: "220Ω Resistor")]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [
                ObservedComponent(identifier: "resistor_220", name: "220Ω Resistor", confidence: 0.90),
                ObservedComponent(identifier: nil, name: "Unidentified Object", confidence: 0.40)
            ],
            overallConfidence: 0.85
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .incorrect)
        XCTAssertTrue(result.issues.contains { $0.type == .unexpectedComponent })
    }
    
    // MARK: - Test 6: Physical Domain Furniture Dowel Comparison (Universal Scale)
    func testPhysicalDomainFurnitureDowelComparison() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [
                ExpectedComponent(identifier: "part_dowel_8mm", name: "Wooden Dowels"),
                ExpectedComponent(identifier: "part_side_panel", name: "Side Panel")
            ],
            requiredPositions: [
                ExpectedPosition(componentID: "part_dowel_8mm", targetDescription: "Inner face of side panel pre-drilled holes")
            ]
        )
        
        let observed = ObservedAssemblyState(
            detectedComponents: [
                ObservedComponent(identifier: "part_dowel_8mm", name: "Wooden Dowel", confidence: 0.88),
                ObservedComponent(identifier: "part_side_panel", name: "Side Panel", confidence: 0.92)
            ],
            detectedPositions: [
                ObservedPosition(componentID: "part_dowel_8mm", detectedDescription: "Inner face of side panel pre-drilled holes", confidence: 0.86)
            ],
            overallConfidence: 0.88
        )
        
        let result = comparator.compare(expected: expected, observed: observed)
        
        XCTAssertEqual(result.status, .correct)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.matchedComponents.count, 2)
    }
    
    // MARK: - Test 7: Multimodal Acoustic Snap Boost
    func testMultimodalAcousticCorroborationBoost() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "part_dowel_8mm", name: "Wooden Dowel")]
        )
        
        // Borderline visual confidence (0.68 is below default minimumCorrectConfidence 0.75)
        let observed = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "part_dowel_8mm", name: "Wooden Dowel", confidence: 0.68)],
            overallConfidence: 0.68
        )
        
        // Without acoustic snap: uncertain
        let resultWithoutAcoustic = comparator.compare(expected: expected, observed: observed, hasAcousticCorroboration: false)
        XCTAssertEqual(resultWithoutAcoustic.status, .uncertain)
        
        // With acoustic snap: boosted +0.15 (0.83 >= 0.75), passes as correct!
        let resultWithAcoustic = comparator.compare(expected: expected, observed: observed, hasAcousticCorroboration: true)
        XCTAssertEqual(resultWithAcoustic.status, .correct)
    }
    
    // MARK: - Test 8: False Positive Prevention with Tokenized Matching (H-2)
    func testFalsePositivePreventionWithTokenizedMatching() {
        let expected = ExpectedAssemblyState(
            stepID: UUID(),
            stepOrder: 1,
            requiredComponents: [ExpectedComponent(identifier: "part_cap_100u", name: "Capacitor")]
        )
        
        // "Captain's Wheel" should NOT match "Capacitor" or "cap"
        let observedFalseCap = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "part_ship_wheel", name: "Captain's Wheel", confidence: 0.90)],
            overallConfidence: 0.90
        )
        let resultFalseCap = comparator.compare(expected: expected, observed: observedFalseCap)
        XCTAssertEqual(resultFalseCap.status, .incorrect)
        XCTAssertTrue(resultFalseCap.issues.contains { $0.type == .missingComponent })
        
        // Real capacitor DOES match
        let observedRealCap = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "part_cap", name: "100uF Cap", confidence: 0.90)],
            overallConfidence: 0.90
        )
        let resultRealCap = comparator.compare(expected: expected, observed: observedRealCap)
        XCTAssertEqual(resultRealCap.status, .correct)
    }
}

