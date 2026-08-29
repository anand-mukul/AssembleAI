//
//  VoiceOutputTests.swift
//  AssembleAI
//

import XCTest
@testable import AssembleAI

final class VoiceOutputTests: XCTestCase {
    
    private var responseProvider: DeterministicTutorResponseProvider!
    private var mockVoiceService: MockVoiceOutputService!
    private var step1: AssemblyStep!
    
    override func setUp() {
        super.setUp()
        responseProvider = DeterministicTutorResponseProvider()
        mockVoiceService = MockVoiceOutputService()
        
        step1 = AssemblyStep(
            id: UUID(),
            projectId: UUID(),
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place 220Ω resistor bridging Row 10 to Row 15"
        )
    }
    
    override func tearDown() {
        responseProvider = nil
        mockVoiceService = nil
        step1 = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Deterministic Response Generation
    func testResponseGenerationFromDecisions() {
        // 1. Instruct Decision
        let instructDecision = InterventionDecision(action: .instruct(step: step1), reason: "Start")
        let instructResponse = responseProvider.response(for: instructDecision)
        XCTAssertNotNil(instructResponse)
        XCTAssertTrue(instructResponse?.text.contains("Insert 220Ω Resistor") == true)
        XCTAssertEqual(instructResponse?.priority, .normal)
        
        // 2. Confirm Decision
        let confirmDecision = InterventionDecision(action: .confirm(step: step1), reason: "Match")
        let confirmResponse = responseProvider.response(for: confirmDecision)
        XCTAssertNotNil(confirmResponse)
        XCTAssertTrue(confirmResponse?.text.contains("Perfect") == true || confirmResponse?.text.contains("Great job") == true || confirmResponse?.text.contains("Nicely done") == true)
        XCTAssertEqual(confirmResponse?.priority, .normal)
        
        // 3. Correct Decision (Explicit)
        let correctDecision = InterventionDecision(action: .correct(description: "Shift lead to Row 15", level: .explicit), reason: "Mistake")
        let correctResponse = responseProvider.response(for: correctDecision)
        XCTAssertNotNil(correctResponse)
        XCTAssertTrue(correctResponse?.text.contains("Check your placement") == true)
        XCTAssertEqual(correctResponse?.priority, .high)
        
        // 4. Request Better View
        let viewDecision = InterventionDecision(action: .requestBetterView(explanation: "Lighting is low"), reason: "Occlusion")
        let viewResponse = responseProvider.response(for: viewDecision)
        XCTAssertNotNil(viewResponse)
        XCTAssertTrue(viewResponse?.text.contains("I need a clearer view") == true)
        
        // 5. Offer Help
        let helpDecision = InterventionDecision(action: .offerHelp(step: step1, attemptCount: 2), reason: "Stuck")
        let helpResponse = responseProvider.response(for: helpDecision)
        XCTAssertNotNil(helpResponse)
        XCTAssertTrue(helpResponse?.text.contains("Need a hand") == true)
        
        // 6. Respond to User
        let userDecision = InterventionDecision(action: .respondToUser(query: "polarities"), reason: "Query")
        let userResponse = responseProvider.response(for: userDecision)
        XCTAssertNotNil(userResponse)
        XCTAssertEqual(userResponse?.priority, .immediate)
        
        // 7. Silent Decision -> Returns nil
        let silentDecision = InterventionDecision.silent(reason: "No changes")
        let silentResponse = responseProvider.response(for: silentDecision)
        XCTAssertNil(silentResponse, "Silent decisions must produce nil tutor response")
    }
    
    // MARK: - Test 2: Voice Service Playback & State
    func testVoiceServicePlaybackLifecycle() async {
        XCTAssertEqual(await mockVoiceService.state, .idle)
        
        let response = TutorResponse(text: "Hello World", priority: .normal)
        await mockVoiceService.speak(response)
        
        XCTAssertEqual(await mockVoiceService.state, .speaking)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 1)
        XCTAssertEqual(mockVoiceService.spokenResponses.first?.text, "Hello World")
        
        await mockVoiceService.pause()
        XCTAssertEqual(await mockVoiceService.state, .paused)
        XCTAssertEqual(mockVoiceService.pauseCount, 1)
        
        await mockVoiceService.resume()
        XCTAssertEqual(await mockVoiceService.state, .speaking)
        XCTAssertEqual(mockVoiceService.resumeCount, 1)
        
        await mockVoiceService.stop()
        XCTAssertEqual(await mockVoiceService.state, .idle)
        XCTAssertEqual(mockVoiceService.stopCount, 1)
    }
    
    // MARK: - Test 3: Priority Interruption / Stale Speech Preemption
    func testPriorityPreemption() async {
        let normalResponse = TutorResponse(text: "Standard instruction playing...", priority: .normal)
        let highPriorityResponse = TutorResponse(text: "Urgent correction needed!", priority: .high)
        let lowPriorityResponse = TutorResponse(text: "Low background tip...", priority: .low)
        
        // 1. Start normal speech
        await mockVoiceService.speak(normalResponse)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 1)
        XCTAssertEqual(mockVoiceService.stopCount, 0)
        
        // 2. High priority speech arrives -> Interrupts normal speech!
        await mockVoiceService.speak(highPriorityResponse)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 2)
        XCTAssertEqual(mockVoiceService.stopCount, 1, "High priority response must interrupt active lower priority speech")
        XCTAssertEqual(mockVoiceService.spokenResponses.last?.text, "Urgent correction needed!")
        
        // 3. Low priority speech arrives while high priority is speaking -> Dropped!
        await mockVoiceService.speak(lowPriorityResponse)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 2, "Lower priority speech must not preempt active high priority speech")
    }
    
    // MARK: - Test 4: Duplicate Speech Suppression
    func testDuplicateSpeechSuppression() async {
        let response1 = TutorResponse(text: "Perfect. Step complete.", priority: .normal)
        let response2 = TutorResponse(text: "Perfect. Step complete.", priority: .normal)
        
        await mockVoiceService.speak(response1)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 1)
        
        // Duplicate immediately following
        await mockVoiceService.speak(response2)
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 1, "Duplicate identical speech must be suppressed")
    }
    
    // MARK: - Test 5: End-to-End Decision -> Spoken Response Pipeline
    func testEndToEndDecisionToVoicePipeline() async {
        let decision = InterventionDecision(action: .confirm(step: step1), reason: "All match")
        
        guard let tutorResponse = responseProvider.response(for: decision) else {
            XCTFail("Expected tutor response for confirm decision")
            return
        }
        
        await mockVoiceService.speak(tutorResponse)
        
        XCTAssertEqual(mockVoiceService.spokenResponses.count, 1)
        XCTAssertEqual(await mockVoiceService.state, .speaking)
        XCTAssertTrue(mockVoiceService.spokenResponses.first?.category == "confirmation")
    }
}
