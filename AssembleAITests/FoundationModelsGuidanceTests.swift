//
//  FoundationModelsGuidanceTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class FoundationModelsGuidanceTests: XCTestCase {
    
    private var mockGenerator: MockGuidanceGenerator!
    private let sampleStep = AssemblyStep(
        projectId: UUID(),
        stepOrder: 2,
        title: "Attach 100uF Capacitor to C2 Header",
        instruction: "Insert capacitor leads observing polarity."
    )
    private let sampleIssue = StateIssue(
        type: .wrongConnection,
        title: "Wrong connection",
        explanation: "Wire is connected to 5V instead of GND."
    )
    private let sampleExpected = ExpectedAssemblyState(
        stepID: UUID(),
        stepOrder: 2,
        requiredComponents: [ExpectedComponent(identifier: "capacitor_100uF", name: "100uF Capacitor")]
    )
    private let sampleObserved = ObservedAssemblyState(
        detectedComponents: [ObservedComponent(identifier: "capacitor_100uF", name: "100uF Capacitor", confidence: 0.85)],
        overallConfidence: 0.85
    )
    
    override func setUp() {
        super.setUp()
        mockGenerator = MockGuidanceGenerator()
    }
    
    override func tearDown() {
        mockGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Mock Guidance Generator Fallback
    func testMockGuidanceFallback() async throws {
        let response = try await mockGenerator.generateGuidance(
            issue: sampleIssue,
            expectedState: sampleExpected,
            observedState: sampleObserved
        )
        
        XCTAssertEqual(response.title, "Wrong connection")
        XCTAssertFalse(response.explanation.isEmpty)
        XCTAssertFalse(response.action.isEmpty)
    }
    
    // MARK: - Test 2: Guidance Context Builder Formatting
    func testGuidanceContextBuilder() {
        let context = GuidanceContextBuilder.buildContext(
            step: sampleStep,
            issue: sampleIssue,
            expectedState: sampleExpected,
            observedState: sampleObserved,
            level: .concise,
            attemptNumber: 2
        )
        
        XCTAssertTrue(context.contains("SYSTEM INSTRUCTION"))
        XCTAssertTrue(context.contains("Do not determine whether the physical assembly is correct."))
        XCTAssertTrue(context.contains("NOTICE: The user has attempted this step 2 times."))
    }
    
    // MARK: - Test 3: Guidance Cache Lookup
    func testGuidanceCache() async {
        let key = GuidanceCache.makeKey(stepID: sampleExpected.stepID, issueType: .wrongConnection, level: .concise)
        let sampleResponse = GuidanceResponse(title: "Cached Title", explanation: "Cached Explanation", action: "Cached Action")
        
        await GuidanceCache.shared.set(key: key, response: sampleResponse)
        let retrieved = await GuidanceCache.shared.get(key: key)
        
        XCTAssertEqual(retrieved, sampleResponse)
    }
    
    // MARK: - Test 4: Adaptive Guidance Context
    func testAdaptiveGuidanceLevel() {
        let conciseContext = GuidanceContextBuilder.buildContext(
            step: sampleStep,
            issue: sampleIssue,
            expectedState: sampleExpected,
            observedState: sampleObserved,
            level: .concise,
            attemptNumber: 1
        )
        
        let detailedContext = GuidanceContextBuilder.buildContext(
            step: sampleStep,
            issue: sampleIssue,
            expectedState: sampleExpected,
            observedState: sampleObserved,
            level: .detailed,
            attemptNumber: 1
        )
        
        XCTAssertTrue(conciseContext.contains("Concise"))
        XCTAssertTrue(detailedContext.contains("Detailed"))
    }
}
