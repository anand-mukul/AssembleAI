//
//  VoiceInputTests.swift
//  AssembleAI
//

import XCTest
@testable import AssembleAI

@MainActor
final class VoiceInputTests: XCTestCase {
    
    private var intentParser: VoiceIntentParser!
    private var mockVoiceInput: MockVoiceInputService!
    private var mockVoiceOutput: MockVoiceOutputService!
    private var policy: AssistantInterventionPolicy!
    private var responseProvider: DeterministicTutorResponseProvider!
    private var step1: AssemblyStep!
    
    override func setUp() {
        super.setUp()
        intentParser = VoiceIntentParser()
        mockVoiceInput = MockVoiceInputService()
        mockVoiceOutput = MockVoiceOutputService()
        policy = AssistantInterventionPolicy()
        responseProvider = DeterministicTutorResponseProvider()
        
        step1 = AssemblyStep(
            id: UUID(),
            projectId: UUID(),
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place 220Ω resistor bridging Row 10 to Row 15"
        )
    }
    
    override func tearDown() {
        intentParser = nil
        mockVoiceInput = nil
        mockVoiceOutput = nil
        policy = nil
        responseProvider = nil
        step1 = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Deterministic Voice Intent Parsing
    func testVoiceIntentParsingPatterns() {
        // Repeat
        XCTAssertEqual(intentParser.parse("repeat that"), .repeatInstruction)
        XCTAssertEqual(intentParser.parse("Say that again!"), .repeatInstruction)
        XCTAssertEqual(intentParser.parse("pardon?"), .repeatInstruction)
        
        // Why
        XCTAssertEqual(intentParser.parse("why?"), .askWhy)
        XCTAssertEqual(intentParser.parse("why is that"), .askWhy)
        XCTAssertEqual(intentParser.parse("explain why"), .askWhy)
        
        // What Next
        XCTAssertEqual(intentParser.parse("what do I do next"), .askWhatNext)
        XCTAssertEqual(intentParser.parse("what's next?"), .askWhatNext)
        XCTAssertEqual(intentParser.parse("what now"), .askWhatNext)
        
        // Where
        XCTAssertEqual(intentParser.parse("where does this go?"), .askWhere)
        XCTAssertEqual(intentParser.parse("where should this go"), .askWhere)
        XCTAssertEqual(intentParser.parse("where do I put this"), .askWhere)
        
        // Help / Stuck
        XCTAssertEqual(intentParser.parse("I'm stuck"), .requestHelp)
        XCTAssertEqual(intentParser.parse("help me please"), .requestHelp)
        XCTAssertEqual(intentParser.parse("help"), .requestHelp)
        
        // Visual Help
        XCTAssertEqual(intentParser.parse("show me"), .requestVisualHelp)
        XCTAssertEqual(intentParser.parse("highlight it"), .requestVisualHelp)
        
        // Continue
        XCTAssertEqual(intentParser.parse("continue"), .continueTask)
        XCTAssertEqual(intentParser.parse("done"), .continueTask)
        
        // Stop
        XCTAssertEqual(intentParser.parse("stop"), .stopTask)
        XCTAssertEqual(intentParser.parse("pause"), .stopTask)
    }
    
    // MARK: - Test 2: Unknown Intent Handling
    func testUnknownIntentDoesNotTriggerAssemblyActions() {
        let unknown1 = intentParser.parse("Tell me a joke.")
        XCTAssertEqual(unknown1, .unknown(transcript: "Tell me a joke."))
        
        let unknown2 = intentParser.parse("What is the weather in Tokyo?")
        XCTAssertEqual(unknown2, .unknown(transcript: "What is the weather in Tokyo?"))
    }
    
    // MARK: - Test 3: Voice Input Service State Lifecycle
    func testVoiceInputServiceLifecycle() async throws {
        let initialState = await mockVoiceInput.state
        XCTAssertEqual(initialState, .idle)
        
        try await mockVoiceInput.startListening()
        let listeningState = await mockVoiceInput.state
        XCTAssertEqual(listeningState, .listening)
        
        await mockVoiceInput.stopListening()
        let finalState = await mockVoiceInput.state
        XCTAssertEqual(finalState, .idle)
    }
    
    // MARK: - Test 4: Partial vs Final Transcript Streaming
    func testTranscriptStreamPartialAndFinalDelivery() async {
        let stream = await mockVoiceInput.transcriptStream
        var receivedMessages: [UserVoiceMessage] = []
        
        let consumerTask = Task {
            for await msg in stream {
                receivedMessages.append(msg)
                if msg.isFinal {
                    break
                }
            }
        }
        
        // Simulate speech recognition progression
        await mockVoiceInput.simulateSpokenTranscript("where", isFinal: false)
        await mockVoiceInput.simulateSpokenTranscript("where does this", isFinal: false)
        await mockVoiceInput.simulateSpokenTranscript("where does this go", isFinal: true)
        
        _ = await consumerTask.result
        
        XCTAssertEqual(receivedMessages.count, 3)
        XCTAssertFalse(receivedMessages[0].isFinal)
        XCTAssertFalse(receivedMessages[1].isFinal)
        XCTAssertTrue(receivedMessages[2].isFinal)
        XCTAssertEqual(receivedMessages.last?.transcript, "where does this go")
    }
    
    // MARK: - Test 5: End-to-End Voice Input -> Intent -> Policy -> Spoken Output Loop
    func testEndToEndVoiceConversationLoop() async {
        let userUtterance = "where does this go?"
        let intent = intentParser.parse(userUtterance)
        XCTAssertEqual(intent, .askWhere)
        
        // Feed into Intervention Policy as User Question event
        let context = TutorContext(currentStep: step1, timeSinceLastInterventionSeconds: 0.2)
        let decision = policy.evaluate(event: .userQuestion(text: userUtterance), context: context)
        
        XCTAssertTrue(decision.shouldIntervene)
        XCTAssertEqual(decision.action, .respondToUser(query: userUtterance))
        
        // Generate Tutor Response
        guard let response = responseProvider.response(for: decision) else {
            XCTFail("Expected response for user query decision")
            return
        }
        
        XCTAssertEqual(response.priority, .immediate)
        
        // Deliver to Voice Output
        await mockVoiceOutput.speak(response)
        let spokenCount = await mockVoiceOutput.spokenResponses.count
        XCTAssertEqual(spokenCount, 1)
        let outputState = await mockVoiceOutput.state
        XCTAssertEqual(outputState, .speaking)
        let firstSpoken = await mockVoiceOutput.spokenResponses.first?.text
        XCTAssertTrue(firstSpoken?.contains("where does this go?") == true)
    }
    
    // MARK: - Test 6: StreamingSpeechService Protocol Conformance & Factory
    func testStreamingSpeechServiceProtocolConformance() async {
        let streamingService = StreamingSpeechService()
        let protocolService: VoiceInputServiceProtocol = streamingService
        let state = await protocolService.state
        XCTAssertEqual(state, .idle)
        
        let continuousService = VoiceInputService.continuousStreaming()
        XCTAssertNotNil(continuousService)
        XCTAssertFalse(continuousService.isListening)
    }
    
    // MARK: - Test 7: Centralized AudioSessionCoordinator Lifecycle
    func testAudioSessionCoordinatorLifecycle() {
        let coordinator = AudioSessionCoordinator.shared
        XCTAssertNotNil(coordinator)
        
        do {
            try coordinator.activateWorkbenchAudioSession()
            XCTAssertTrue(coordinator.isSessionActive)
        } catch {
            XCTAssertNotNil(coordinator.lastErrorMessage)
        }
        
        coordinator.deactivateSession()
        XCTAssertFalse(coordinator.isSessionActive)
    }
}
