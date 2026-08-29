//
//  GuidanceOverlayTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class GuidanceOverlayTests: XCTestCase {
    
    private var provider: DefaultGuidanceProvider!
    private let sampleStep = AssemblyStep(
        projectId: UUID(),
        stepOrder: 2,
        title: "Attach 100uF Capacitor to C2 Header",
        instruction: "Insert capacitor leads observing polarity."
    )
    
    override func setUp() {
        super.setUp()
        provider = DefaultGuidanceProvider()
    }
    
    override func tearDown() {
        provider = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Target Guidance Creation
    func testTargetGuidanceCreation() async {
        let comparison = StateComparison(
            status: .incorrect,
            confidence: 0.80,
            issues: [
                StateIssue(
                    type: .missingComponent,
                    title: "Missing Capacitor",
                    explanation: "Capacitor missing from slot C2."
                )
            ],
            matchedComponents: []
        )
        
        let overlay = await provider.guidance(for: comparison, step: sampleStep, viewSize: CGSize(width: 400, height: 800))
        
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.style, .target)
        XCTAssertNotNil(overlay?.targetRegion)
    }
    
    // MARK: - Test 2: Move Guidance Creation (Source -> Destination)
    func testMoveGuidanceCreation() async {
        let comparison = StateComparison(
            status: .incorrect,
            confidence: 0.85,
            issues: [
                StateIssue(
                    type: .wrongPosition,
                    title: "Wrong position",
                    explanation: "Lead inserted into Row 14 instead of Row 15."
                )
            ],
            matchedComponents: []
        )
        
        let overlay = await provider.guidance(for: comparison, step: sampleStep, viewSize: CGSize(width: 400, height: 800))
        
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.style, .move)
        XCTAssertNotNil(overlay?.sourceRegion)
        XCTAssertNotNil(overlay?.destinationRegion)
    }
    
    // MARK: - Test 3: Text-Only Fallback Guidance
    func testTextOnlyFallbackGuidance() async {
        let comparison = StateComparison(
            status: .incorrect,
            confidence: 0.70,
            issues: [
                StateIssue(
                    type: .unexpectedComponent,
                    title: "Unidentified Object",
                    explanation: "Unknown object near slot."
                )
            ],
            matchedComponents: []
        )
        
        let overlay = await provider.guidance(for: comparison, step: sampleStep, viewSize: CGSize(width: 400, height: 800))
        
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.style, .warning)
        XCTAssertNil(overlay?.targetRegion)
    }
    
    // MARK: - Test 4: Uncertain Guidance
    func testUncertainGuidance() async {
        let comparison = StateComparison(
            status: .uncertain,
            confidence: 0.40,
            issues: [
                StateIssue(
                    type: .insufficientVisualEvidence,
                    title: "Need a clearer view",
                    explanation: "Low visual confidence."
                )
            ],
            matchedComponents: []
        )
        
        let overlay = await provider.guidance(for: comparison, step: sampleStep, viewSize: CGSize(width: 400, height: 800))
        
        XCTAssertNotNil(overlay)
        XCTAssertEqual(overlay?.style, .warning)
        XCTAssertEqual(overlay?.title, "Need a clearer view")
    }
}
