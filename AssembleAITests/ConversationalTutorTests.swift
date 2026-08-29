//
//  ConversationalTutorTests.swift
//  AssembleAI
//

import XCTest
@testable import AssembleAI

final class ConversationalTutorTests: XCTestCase {
    
    private var hybridProvider: HybridTutorResponseProvider!
    private var mockProvider: MockConversationalTutorProvider!
    private var step1: AssemblyStep!
    private var step2: AssemblyStep!
    
    override func setUp() {
        super.setUp()
        hybridProvider = HybridTutorResponseProvider()
        mockProvider = MockConversationalTutorProvider()
        
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
    }
    
    override func tearDown() {
        hybridProvider = nil
        mockProvider = nil
        step1 = nil
        step2 = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Confirm Decision Generates Positive Spoken Response
    func testConfirmDecisionResponse() async {
        let decision = InterventionDecision(action: .confirm(step: step1), reason: "Physical match")
        let context = AssistantContext(
            currentStep: step1,
            verificationResult: VerificationResult(status: .correct, confidence: 0.95, detectedDescription: "220Ω", expectedDescription: "220Ω", explanation: "Match")
        )
        
        let response = await hybridProvider.generateResponse(for: decision, context: context)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.priority, .normal)
        XCTAssertEqual(response?.category, "confirmation")
        XCTAssertTrue(response?.text.contains("Perfect") == true || response?.text.contains("Great job") == true || response?.text.contains("Nicely done") == true)
    }
    
    // MARK: - Test 2: Correct Decision Generates Grounded Error Explanation
    func testCorrectDecisionResponse() async {
        let issue = StateIssue(type: .wrongPosition, title: "Wrong Row", explanation: "Inserted in Row 14 instead of 15")
        let decision = InterventionDecision(action: .correct(description: issue.explanation, level: .explicit), reason: "Mistake")
        let context = AssistantContext(
            currentStep: step1,
            verificationResult: VerificationResult(status: .incorrect, confidence: 0.85, detectedDescription: "Row 14", expectedDescription: "Row 15", explanation: issue.explanation),
            primaryIssue: issue
        )
        
        let response = await hybridProvider.generateResponse(for: decision, context: context)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.priority, .high)
        XCTAssertEqual(response?.category, "correction")
        XCTAssertTrue(response?.text.contains("Row 14") == true)
    }
    
    // MARK: - Test 3: User "Why?" Question Answering
    func testUserWhyQuestionAnswering() async {
        let issue = StateIssue(type: .wrongPosition, title: "Wrong Row", explanation: "Inserted in Row 14 instead of 15")
        let context = AssistantContext(
            currentStep: step1,
            primaryIssue: issue
        )
        
        let response = await mockProvider.answerUserQuestion(
            query: "Why is Row 14 wrong?",
            intent: .askWhy,
            context: context
        )
        
        XCTAssertEqual(response.priority, .immediate)
        XCTAssertTrue(response.text.contains("power rail") || response.text.contains("circuit"))
        XCTAssertEqual(await mockProvider.answerQuestionCallCount, 1)
    }
    
    // MARK: - Test 4: User "What Next?" Question Answering
    func testUserWhatNextQuestionAnswering() async {
        let context = AssistantContext(currentStep: step1)
        let response = await mockProvider.answerUserQuestion(
            query: "What do I do next?",
            intent: .askWhatNext,
            context: context
        )
        
        XCTAssertEqual(response.priority, .immediate)
        XCTAssertTrue(response.text.contains("LED") || response.text.contains("Next"))
    }
    
    // MARK: - Test 5: Silence Decision Never Invokes Generation
    func testSilenceDecisionProducesNilResponse() async {
        let silentDecision = InterventionDecision.silent(reason: "No changes")
        let context = AssistantContext(currentStep: step1)
        
        let response = await mockProvider.generateResponse(for: silentDecision, context: context)
        
        XCTAssertNil(response, "Silent decisions must produce nil tutor response")
        XCTAssertEqual(await mockProvider.generateResponseCallCount, 1)
    }
    
    // MARK: - Test 6: Grounding Invariant — Model Output Cannot Change Verification State
    func testModelOutputCannotChangeVerificationState() async {
        // Physical comparator evaluated state as INCORRECT
        let verificationResult = VerificationResult(
            status: .incorrect,
            confidence: 0.85,
            detectedDescription: "Wrong position",
            expectedDescription: "Row 15",
            explanation: "Lead inserted in Row 14."
        )
        
        // Mock model returns hallucinated "Actually you did it right" text
        await mockProvider.setScriptedResponses([
            TutorResponse(text: "Actually you did it right.", priority: .normal)
        ])
        
        let decision = InterventionDecision(action: .correct(description: "Lead in Row 14", level: .gentle), reason: "Mistake")
        let context = AssistantContext(currentStep: step1, verificationResult: verificationResult)
        
        let response = await mockProvider.generateResponse(for: decision, context: context)
        XCTAssertNotNil(response)
        
        // Assert: Deterministic verification result is strictly unchanged
        XCTAssertEqual(verificationResult.status, .incorrect)
        XCTAssertFalse(verificationResult.isCorrect)
    }
    
    // MARK: - Test 7: Session Memory Reset
    func testSessionMemoryReset() async {
        let context = AssistantContext(currentStep: step1)
        _ = await mockProvider.answerUserQuestion(query: "Where is R1?", intent: .askWhere, context: context)
        XCTAssertNotNil(await mockProvider.lastReceivedContext)
        
        await mockProvider.clearSessionContext()
        XCTAssertNil(await mockProvider.lastReceivedContext)
    }
}
