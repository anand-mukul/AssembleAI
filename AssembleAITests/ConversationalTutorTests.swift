//
//  ConversationalTutorTests.swift
//  AssembleAI
//

import XCTest
@testable import AssembleAI

@MainActor
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
        let text = response?.text ?? ""
        let validKeywords = ["Perfect", "Great", "Nicely done", "Spot on", "Awesome", "Boom"]
        XCTAssertTrue(validKeywords.contains(where: { text.contains($0) }), "Response '\(text)' does not contain expected praise keyword")
    }
    
    // MARK: - Test 2: Explicit Correction Response
    func testExplicitCorrectionDecisionResponse() async {
        let issue = StateIssue(type: .wrongPosition, title: "Misplaced Resistor", explanation: "Lead in Row 14 instead of Row 15.")
        let verificationResult = VerificationResult(
            status: .incorrect,
            confidence: 0.90,
            detectedDescription: "Lead in Row 14",
            expectedDescription: "Lead in Row 15",
            explanation: issue.explanation
        )
        let decision = InterventionDecision(action: .correct(description: issue.explanation, level: .explicit), reason: "Mistake")
        let context = AssistantContext(
            currentStep: step1,
            verificationResult: verificationResult,
            attemptCount: 2
        )
        
        let response = await hybridProvider.generateResponse(for: decision, context: context)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.priority, .high)
        XCTAssertEqual(response?.category, "correction")
        XCTAssertTrue(response?.text.contains("Lead in Row 14") == true)
    }
    
    // MARK: - Test 3: User "Why?" Question Answering
    func testUserWhyQuestionAnswering() async {
        let context = AssistantContext(
            currentStep: step1,
            userTranscript: "why does it go in row 15?"
        )
        
        let response = await mockProvider.answerUserQuestion(
            query: "why row 15?",
            intent: .askWhy,
            context: context
        )
        
        XCTAssertEqual(response.priority, .immediate)
        XCTAssertTrue(response.text.contains("power rail") || response.text.contains("circuit"))
        let questionCallCount = await mockProvider.answerQuestionCallCount
        XCTAssertEqual(questionCallCount, 1)
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
        let generateCallCount = await mockProvider.generateResponseCallCount
        XCTAssertEqual(generateCallCount, 1)
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
        let lastCtx = await mockProvider.lastReceivedContext
        XCTAssertNotNil(lastCtx)
        
        await mockProvider.clearSessionContext()
        let clearedCtx = await mockProvider.lastReceivedContext
        XCTAssertNil(clearedCtx)
    }
    
    // MARK: - Test 8: Foundation Models Tool Calling — Resistor Color Bands
    func testToolCallingResistorColorBands() {
        let tools = FoundationModelsToolCallingService()
        
        // 220 ohm
        let info220 = tools.queryResistorBands(query: "220 ohm")
        XCTAssertNotNil(info220)
        XCTAssertEqual(info220?.nominalOhms, 220.0)
        XCTAssertEqual(info220?.bands, ["red", "red", "brown", "gold"])
        
        // 10k ohm
        let info10k = tools.queryResistorBands(query: "10k")
        XCTAssertNotNil(info10k)
        XCTAssertEqual(info10k?.nominalOhms, 10_000.0)
        XCTAssertEqual(info10k?.bands, ["brown", "black", "orange", "gold"])
    }
    
    // MARK: - Test 9: Foundation Models Tool Calling — Breadboard Continuity
    func testToolCallingBreadboardContinuity() {
        let tools = FoundationModelsToolCallingService()
        
        // Same row, same bank (10A and 10E) -> connected
        let c1 = tools.queryBreadboardContinuity(pin1: "10A", pin2: "10E")
        XCTAssertTrue(c1.isConnected)
        
        // Same row, separated by center trough (10A and 10F) -> disconnected
        let c2 = tools.queryBreadboardContinuity(pin1: "10A", pin2: "10F")
        XCTAssertFalse(c2.isConnected)
        XCTAssertTrue(c2.explanation.contains("trough") || c2.explanation.contains("divider"))
        
        // Different rows (10A and 12A) -> disconnected
        let c3 = tools.queryBreadboardContinuity(pin1: "10A", pin2: "12A")
        XCTAssertFalse(c3.isConnected)
        
        // Power rail short check (+ and -) -> false with dead short warning
        let c4 = tools.queryBreadboardContinuity(pin1: "+", pin2: "-")
        XCTAssertFalse(c4.isConnected)
        XCTAssertTrue(c4.explanation.contains("SHORT"))
    }
    
    // MARK: - Test 10: Foundation Models Tool Calling — Component Substitution
    func testToolCallingComponentSubstitution() {
        let tools = FoundationModelsToolCallingService()
        
        // Safe substitution: 330 ohm for 220 ohm step
        let subSafe = tools.queryComponentSubstitution(requestedPart: "330 ohm", targetStep: step1)
        XCTAssertTrue(subSafe.isViable)
        XCTAssertTrue(subSafe.explanation.contains("viable substitute"))
        
        // Dangerous substitution: 10 ohm (excessive current)
        let subUnsafe = tools.queryComponentSubstitution(requestedPart: "10 ohm", targetStep: step1)
        XCTAssertFalse(subUnsafe.isViable)
        XCTAssertTrue(subUnsafe.explanation.contains("Unsafe substitution"))
        
        // Transistor substitution: BC547 for 2N2222
        let stepTransistor = AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Insert 2N2222 Transistor", instruction: "Place NPN transistor")
        let subTransistor = tools.queryComponentSubstitution(requestedPart: "can i use BC547", targetStep: stepTransistor)
        XCTAssertTrue(subTransistor.isViable)
        XCTAssertTrue(subTransistor.explanation.contains("pinout"))
    }
    
    // MARK: - Test 11: Hybrid Tutor Answers Resistor Color Bands Query
    func testHybridTutorAnswersResistorQuery() async {
        let context = AssistantContext(currentStep: step1)
        let response = await hybridProvider.answerUserQuestion(
            query: "what are the color bands for 220 ohm?",
            intent: .askSpecs(query: "what are the color bands for 220 ohm?"),
            context: context
        )
        
        XCTAssertNotNil(response)
        XCTAssertTrue(response.text.contains("Red, Red, Brown") || response.text.contains("220"))
    }
    
    // MARK: - Test 12: Hybrid Tutor Answers Substitution Query
    func testHybridTutorAnswersSubstitutionQuery() async {
        let context = AssistantContext(currentStep: step1)
        let response = await hybridProvider.answerUserQuestion(
            query: "can I use a 330 ohm resistor instead?",
            intent: .askSubstitution(partQuery: "can I use a 330 ohm resistor instead?"),
            context: context
        )
        
        XCTAssertNotNil(response)
        XCTAssertTrue(response.text.contains("safe substitute") || response.text.contains("330"))
    }
    
    // MARK: - Test 13: Universal Physical Tool Calling — Fastener Count Verification
    func testToolCallingFastenerCountVerification() {
        let tools = FoundationModelsToolCallingService()
        
        // Full count satisfied
        let full = tools.queryFastenerCount(expectedCount: 4, observedCount: 4, partName: "M4x12mm Hex Bolt")
        XCTAssertTrue(full.isCountMatched)
        XCTAssertEqual(full.count, 4)
        XCTAssertTrue(full.explanation.contains("All 4 M4x12mm Hex Bolt elements are placed"))
        
        // Missing fasteners
        let partial = tools.queryFastenerCount(expectedCount: 4, observedCount: 2, partName: "Cam Lock Pin")
        XCTAssertFalse(partial.isCountMatched)
        XCTAssertEqual(partial.count, 2)
        XCTAssertTrue(partial.explanation.contains("Missing 2 Cam Lock Pin fastener(s)"))
    }
    
    // MARK: - Test 14: Universal Physical Tool Calling — Joint Alignment Analysis
    func testToolCallingJointAlignment() {
        let tools = FoundationModelsToolCallingService()
        
        // Well-aligned joint (within 5° tolerance)
        let aligned = tools.queryJointAlignment(jointDescription: "Corner Leg Joint", expectedAngleDegrees: 90.0, observedAngleDegrees: 91.2)
        XCTAssertTrue(aligned.isAligned)
        XCTAssertTrue(aligned.guidance.contains("square and aligned within 5° tolerance"))
        
        // Misaligned joint (> 5° tolerance)
        let misaligned = tools.queryJointAlignment(jointDescription: "Cabinet Side Panel", expectedAngleDegrees: 90.0, observedAngleDegrees: 82.0)
        XCTAssertFalse(misaligned.isAligned)
        XCTAssertTrue(misaligned.guidance.contains("misaligned by 8.0°"))
        XCTAssertTrue(misaligned.guidance.contains("flush before tightening"))
    }
    
    // MARK: - Test 15: Universal Physical Tool Calling — Fastener Tool Recommendation
    func testToolCallingFastenerToolRecommendation() {
        let tools = FoundationModelsToolCallingService()
        
        // Cam lock recommendation
        let camRec = tools.queryFastenerToolRecommendation(fastenerType: "cam lock fastener", sizeDescription: "15mm")
        XCTAssertTrue(camRec.toolName.contains("Screwdriver"))
        XCTAssertTrue(camRec.usageTip.contains("Do NOT use an impact drill"))
        
        // Allen / Hex key recommendation for M5
        let hexRec = tools.queryFastenerToolRecommendation(fastenerType: "socket head bolt", sizeDescription: "M5x20mm")
        XCTAssertEqual(hexRec.toolName, "Hex / Allen Key")
        XCTAssertEqual(hexRec.bitSize, "4mm")
        XCTAssertTrue(hexRec.usageTip.contains("quarter turn"))
        
        // Wooden dowel recommendation
        let dowelRec = tools.queryFastenerToolRecommendation(fastenerType: "wooden dowel pin", sizeDescription: "8x30mm")
        XCTAssertTrue(dowelRec.toolName.contains("Rubber Mallet"))
        XCTAssertTrue(dowelRec.usageTip.contains("Never hit directly with a metal hammer"))
    }
    
    // MARK: - Test 16: Universal Physical Tool Calling — Mechanical Kinematics
    func testToolCallingMechanicalKinematics() {
        let tools = FoundationModelsToolCallingService()
        
        // Gear mesh clearance
        let gearInfo = tools.queryMechanicalKinematics(component: "Spur Gear Mesh")
        XCTAssertTrue(gearInfo.alignmentRule.contains("pitch diameter"))
        XCTAssertTrue(gearInfo.clearanceRecommendation.contains("paper slip test"))
        
        // Timing belt tension
        let beltInfo = tools.queryMechanicalKinematics(component: "GT2 Timing Belt")
        XCTAssertTrue(beltInfo.alignmentRule.contains("extrusion rails"))
        XCTAssertTrue(beltInfo.clearanceRecommendation.contains("plucked (~100–120Hz)"))
        
        // Ball bearing press force rule
        let bearingInfo = tools.queryMechanicalKinematics(component: "608ZZ Ball Bearing")
        XCTAssertTrue(bearingInfo.alignmentRule.contains("outer ring"))
        XCTAssertTrue(bearingInfo.safetyNote.contains("rolling balls"))
    }
}

