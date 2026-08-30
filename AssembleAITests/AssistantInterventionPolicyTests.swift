//
//  AssistantInterventionPolicyTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class AssistantInterventionPolicyTests: XCTestCase {
    
    private var policy: AssistantInterventionPolicy!
    private var step1: AssemblyStep!
    private var step2: AssemblyStep!
    
    override func setUp() {
        super.setUp()
        let projectID = UUID()
        step1 = AssemblyStep(
            id: UUID(),
            projectId: projectID,
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place 220Ω resistor bridging Row 10 to Row 15"
        )
        step2 = AssemblyStep(
            id: UUID(),
            projectId: projectID,
            stepOrder: 2,
            title: "Insert 100uF Capacitor",
            instruction: "Place capacitor in C2 header slot"
        )
        
        policy = AssistantInterventionPolicy(
            configuration: InterventionPolicyConfiguration(
                minimumCooldownSeconds: 4.0,
                stuckDetectionThresholdSeconds: 15.0,
                uncertainThresholdCount: 3,
                allowInitialInstruction: true
            )
        )
    }
    
    override func tearDown() {
        policy = nil
        step1 = nil
        step2 = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Step Started Event
    func testStepStartedProducesInstruction() {
        let context = TutorContext(currentStep: step1)
        let decision = policy.evaluate(event: .stepStarted(step: step1), context: context)
        
        XCTAssertTrue(decision.shouldIntervene)
        XCTAssertEqual(decision.action, .instruct(step: step1))
    }
    
    // MARK: - Test 2: Correct State Confirmation
    func testCorrectStateProducesConfirmationOnce() {
        let correctResult = VerificationResult(
            status: .correct,
            confidence: 0.95,
            detectedDescription: "220Ω Resistor",
            expectedDescription: "220Ω Resistor",
            explanation: "All matches."
        )
        
        let context = TutorContext(
            currentStep: step1,
            timeSinceLastInterventionSeconds: 10.0,
            lastVerificationResult: correctResult
        )
        
        // 1st Correct Event -> Should Confirm
        let decision1 = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context)
        XCTAssertTrue(decision1.shouldIntervene)
        XCTAssertEqual(decision1.action, .confirm(step: step1))
        
        // 2nd Identical Correct Event -> Should Remain Silent (Anti-Spam)
        let decision2 = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context)
        XCTAssertFalse(decision2.shouldIntervene)
        XCTAssertEqual(decision2.action, .remainSilent)
    }
    
    // MARK: - Test 3: Anti-Spam — 100 Identical Correct Events
    func testAntiSpam100IdenticalCorrectEvents() {
        let correctResult = VerificationResult(
            status: .correct,
            confidence: 0.95,
            detectedDescription: "220Ω Resistor",
            expectedDescription: "220Ω Resistor",
            explanation: "All matches."
        )
        let context = TutorContext(
            currentStep: step1,
            timeSinceLastInterventionSeconds: 10.0,
            lastVerificationResult: correctResult
        )
        
        var confirmCount = 0
        var silentCount = 0
        
        for _ in 0..<100 {
            let decision = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context)
            if case .confirm = decision.action {
                confirmCount += 1
            } else if case .remainSilent = decision.action {
                silentCount += 1
            }
        }
        
        XCTAssertEqual(confirmCount, 1, "Exactly one confirmation must be emitted")
        XCTAssertEqual(silentCount, 99, "Subsequent 99 events must remain silent")
    }
    
    // MARK: - Test 4: Error Escalation (Gentle -> Explicit -> Detailed)
    func testErrorEscalationLevels() {
        let incorrectResult = VerificationResult(
            status: .incorrect,
            confidence: 0.85,
            detectedDescription: "Resistor at Row 14",
            expectedDescription: "Resistor at Row 15",
            explanation: "Resistor lead inserted into Row 14 instead of 15."
        )
        
        // 1st Mistake -> Gentle level
        let context1 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        let decision1 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context1)
        XCTAssertTrue(decision1.shouldIntervene)
        if case .correct(_, let level) = decision1.action {
            XCTAssertEqual(level, .gentle)
        } else {
            XCTFail("Expected .correct action")
        }
        
        // 2nd Mistake (after cooldown) -> Explicit level
        let context2 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        let decision2 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context2)
        XCTAssertTrue(decision2.shouldIntervene)
        if case .correct(_, let level) = decision2.action {
            XCTAssertEqual(level, .explicit)
        } else {
            XCTFail("Expected .correct action")
        }
        
        // 3rd Mistake (after cooldown) -> Detailed level
        let context3 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        let decision3 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context3)
        XCTAssertTrue(decision3.shouldIntervene)
        if case .correct(_, let level) = decision3.action {
            XCTAssertEqual(level, .detailed)
        } else {
            XCTFail("Expected .correct action")
        }
    }
    
    // MARK: - Test 5: Cooldown Suppression on Rapid Mistakes
    func testCooldownSuppressesRapidCorrections() {
        let incorrectResult = VerificationResult(
            status: .incorrect,
            confidence: 0.85,
            detectedDescription: "Wrong position",
            expectedDescription: "Target slot",
            explanation: "Component misplaced."
        )
        
        // 1st Mistake (Allowed)
        let context1 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        let d1 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context1)
        XCTAssertTrue(d1.shouldIntervene)
        
        // Rapid 2nd Mistake arriving only 1.0s later (below 4.0s cooldown -> Suppressed)
        let context2 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 1.0)
        let d2 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context2)
        XCTAssertFalse(d2.shouldIntervene)
        XCTAssertEqual(d2.action, .remainSilent)
    }
    
    // MARK: - Test 6: Persistent Uncertainty vs Transient Uncertainty
    func testUncertaintyHandling() {
        let uncertainResult = VerificationResult(
            status: .uncertain,
            confidence: 0.40,
            detectedDescription: "Low lighting",
            expectedDescription: "Resistor",
            explanation: "View is occluded."
        )
        
        // 1st Uncertain Event -> Remain Silent (transient)
        let context = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        let d1 = policy.evaluate(event: .verificationUpdated(result: uncertainResult), context: context)
        XCTAssertFalse(d1.shouldIntervene)
        
        // 2nd Uncertain Event -> Still Silent
        let d2 = policy.evaluate(event: .verificationUpdated(result: uncertainResult), context: context)
        XCTAssertFalse(d2.shouldIntervene)
        
        // 3rd Consecutive Uncertain Event -> Triggers Request Better View!
        let d3 = policy.evaluate(event: .verificationUpdated(result: uncertainResult), context: context)
        XCTAssertTrue(d3.shouldIntervene)
        if case .requestBetterView = d3.action {
            // Expected
        } else {
            XCTFail("Expected .requestBetterView on persistent uncertainty")
        }
    }
    
    // MARK: - Test 7: Stuck Inactivity Detection
    func testStuckDetectionTriggersOfferHelp() {
        // Active for 5 seconds (< 15s threshold) -> Silent
        let context1 = TutorContext(currentStep: step1, timeSinceStepStartedSeconds: 5.0, timeSinceLastInterventionSeconds: 10.0)
        let d1 = policy.evaluate(event: .inactiveTimeout, context: context1)
        XCTAssertFalse(d1.shouldIntervene)
        
        // Active for 16 seconds (>= 15s threshold) -> Offer Help!
        let context2 = TutorContext(currentStep: step1, timeSinceStepStartedSeconds: 16.0, timeSinceLastInterventionSeconds: 10.0)
        let d2 = policy.evaluate(event: .inactiveTimeout, context: context2)
        XCTAssertTrue(d2.shouldIntervene)
        if case .offerHelp(let step, _) = d2.action {
            XCTAssertEqual(step.id, step1.id)
        } else {
            XCTFail("Expected .offerHelp action")
        }
    }
    
    // MARK: - Test 8: User-Initiated Question Bypasses Cooldown
    func testUserQuestionBypassesCooldown() {
        // Even with 0.1s since last intervention (deep within cooldown)
        let context = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 0.1)
        let decision = policy.evaluate(event: .userQuestion(text: "Why is GND on the blue rail?"), context: context)
        
        XCTAssertTrue(decision.shouldIntervene, "User questions must immediately bypass cooldown")
        XCTAssertEqual(decision.action, .respondToUser(query: "Why is GND on the blue rail?"))
    }
    
    // MARK: - Test 9: Step Change Resets Policy State
    func testStepChangeResetsConfirmationState() {
        let correctResult = VerificationResult(
            status: .correct,
            confidence: 0.95,
            detectedDescription: "Resistor",
            expectedDescription: "Resistor",
            explanation: "All matches."
        )
        let context1 = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        _ = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context1)
        
        // Transition to Step 2
        let context2 = TutorContext(currentStep: step2, timeSinceLastInterventionSeconds: 10.0)
        let decisionStep2 = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context2)
        
        // Should confirm Step 2 without being blocked by Step 1's confirmed flag!
        XCTAssertTrue(decisionStep2.shouldIntervene)
        XCTAssertEqual(decisionStep2.action, .confirm(step: step2))
    }
    
    // MARK: - Test 10: Rapid State Sequence (Incorrect -> Uncertain -> Incorrect -> Correct)
    func testRapidStateSequence() {
        let incorrectResult = VerificationResult(status: .incorrect, confidence: 0.85, detectedDescription: "Wrong", expectedDescription: "Right", explanation: "Misplaced")
        let uncertainResult = VerificationResult(status: .uncertain, confidence: 0.40, detectedDescription: "Low conf", expectedDescription: "Right", explanation: "Low light")
        let correctResult = VerificationResult(status: .correct, confidence: 0.95, detectedDescription: "Right", expectedDescription: "Right", explanation: "Match")
        
        let context = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 10.0)
        
        // 1. Incorrect -> Corrective decision
        let d1 = policy.evaluate(event: .verificationUpdated(result: incorrectResult), context: context)
        XCTAssertTrue(d1.shouldIntervene)
        
        // 2. Transient Uncertain -> Silent
        let d2 = policy.evaluate(event: .verificationUpdated(result: uncertainResult), context: context)
        XCTAssertFalse(d2.shouldIntervene)
        
        // 3. Correct -> Confirm decision
        let d3 = policy.evaluate(event: .verificationUpdated(result: correctResult), context: context)
        XCTAssertTrue(d3.shouldIntervene)
        XCTAssertEqual(d3.action, .confirm(step: step1))
    }
}
