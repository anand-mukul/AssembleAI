//
//  DemoModeTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class DemoModeTests: XCTestCase {
    
    private var mockService: MockVerificationService!
    
    override func setUp() {
        super.setUp()
        mockService = MockVerificationService()
    }
    
    override func tearDown() {
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - Test Deterministic Demo Script Outcomes
    func testDeterministicDemoScriptOutcomes() async throws {
        // Step 1 -> Correct
        let step1 = AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Step 1", instruction: "Resistor")
        let res1 = try await mockService.verifyStep(step1, image: nil)
        XCTAssertEqual(res1.status, .correct)
        
        // Step 2 -> Incorrect (wrongPosition)
        let step2 = AssemblyStep(projectId: UUID(), stepOrder: 2, title: "Step 2", instruction: "Capacitor")
        let res2 = try await mockService.verifyStep(step2, image: nil)
        XCTAssertEqual(res2.status, .incorrect)
        XCTAssertTrue(res2.explanation.contains("Row 14") || res2.explanation.contains("slot"))
        
        // Step 3 -> Uncertain (insufficientVisualEvidence)
        let step3 = AssemblyStep(projectId: UUID(), stepOrder: 3, title: "Step 3", instruction: "LED")
        let res3 = try await mockService.verifyStep(step3, image: nil)
        XCTAssertEqual(res3.status, .uncertain)
        
        // Step 4 -> Incorrect (wrongConnection)
        let step4 = AssemblyStep(projectId: UUID(), stepOrder: 4, title: "Step 4", instruction: "Wire")
        let res4 = try await mockService.verifyStep(step4, image: nil)
        XCTAssertEqual(res4.status, .incorrect)
        
        // Step 5 -> Correct
        let step5 = AssemblyStep(projectId: UUID(), stepOrder: 5, title: "Step 5", instruction: "Jumper Wire")
        let res5 = try await mockService.verifyStep(step5, image: nil)
        XCTAssertEqual(res5.status, .correct)
    }
}
