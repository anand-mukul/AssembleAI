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
}
