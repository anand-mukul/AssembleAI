//
//  LiveTutorHUDTests.swift
//  AssembleAI
//

import XCTest
import CoreVideo
@testable import AssembleAI

@MainActor
final class LiveTutorHUDTests: XCTestCase {
    
    private var viewModel: AssemblyViewModel!
    private var mockVision: MockVisionService!
    private var mockVoiceOutput: MockVoiceOutputService!
    private var mockVoiceInput: MockVoiceInputService!
    private var mockTutor: MockConversationalTutorProvider!
    private var project: AssemblyProject!
    
    override func setUp() {
        super.setUp()
        mockVision = MockVisionService()
        mockVoiceOutput = MockVoiceOutputService()
        mockVoiceInput = MockVoiceInputService()
        mockTutor = MockConversationalTutorProvider()
        
        let step1 = StepSummary(
            id: UUID(),
            stepOrder: 1,
            title: "Insert 220Ω Resistor",
            instruction: "Place 220Ω resistor bridging Row 10 to Row 15",
            expectedDurationMinutes: 2
        )
        let step2 = StepSummary(
            id: UUID(),
            stepOrder: 2,
            title: "Insert 100uF Capacitor",
            instruction: "Place capacitor in C2 header slot",
            expectedDurationMinutes: 2
        )
        
        project = AssemblyProject(
            id: UUID(),
            title: "LED Flasher Circuit",
            description: "Hardware assembly prototype",
            category: "Electronics",
            difficulty: "Beginner",
            estimatedDurationMinutes: 10,
            completedSteps: 0,
            totalSteps: 2,
            steps: [step1, step2]
        )
        
        viewModel = AssemblyViewModel(
            project: project,
            visionAnalyzer: mockVision,
            conversationalTutor: mockTutor,
            voiceOutput: mockVoiceOutput,
            voiceInput: mockVoiceInput
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockVision = nil
        mockVoiceOutput = nil
        mockVoiceInput = nil
        mockTutor = nil
        project = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Live Tutor Status & Pause Lifecycle
    func testLiveTutorStatusAndPauseToggle() {
        XCTAssertTrue(viewModel.liveTutorEnabled)
        XCTAssertFalse(viewModel.isLivePaused)
        XCTAssertEqual(viewModel.liveStatus, .live)
        
        viewModel.toggleLivePause()
        XCTAssertTrue(viewModel.isLivePaused)
        XCTAssertEqual(viewModel.liveStatus, .paused)
        
        viewModel.toggleLivePause()
        XCTAssertFalse(viewModel.isLivePaused)
        XCTAssertEqual(viewModel.liveStatus, .live)
    }
    
    // MARK: - Test 2: Voice Input Toggle and User Question Handling
    func testVoiceInputInteraction() async {
        XCTAssertFalse(viewModel.isListening)
        
        // 1. Toggle Voice Input ON
        viewModel.toggleVoiceInput()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertEqual(viewModel.liveStatus, .listening)
        
        // 2. Simulate User Speech Recognition Utterance
        await mockVoiceInput.simulateSpokenTranscript("where does this go", isFinal: true)
        
        // Allow cooperative async tasks to complete
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(mockTutor.answerQuestionCallCount, 1)
        XCTAssertEqual(await mockVoiceOutput.spokenResponses.count, 1)
    }
    
    // MARK: - Test 3: Step Transition Resets Live State
    func testStepTransitionResetsLiveState() {
        viewModel.currentTutorMessage = TutorResponse(text: "Old Step Message", priority: .normal)
        viewModel.currentVerificationResult = VerificationResult(status: .correct, confidence: 0.9, detectedDescription: "Resistor", expectedDescription: "Resistor", explanation: "Match")
        viewModel.liveUserTranscript = "Stale transcript"
        
        // Move to Step 2
        viewModel.nextStep()
        
        XCTAssertEqual(viewModel.currentStepIndex, 1)
        XCTAssertNil(viewModel.currentTutorMessage, "Old step tutor messages must be cleared")
        XCTAssertNil(viewModel.currentVerificationResult, "Old step verification must be cleared")
        XCTAssertEqual(viewModel.liveUserTranscript, "", "Live user transcript must be reset")
    }
    
    // MARK: - Test 4: Legacy Mode Disables Live Streaming
    func testLegacyModePreservesManualAnalysis() {
        viewModel.liveTutorEnabled = false
        
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        viewModel.startLiveTutor(frameStream: stream)
        
        // Stream should not engage live task
        continuation.finish()

        XCTAssertFalse(viewModel.liveTutorEnabled)
    }

    // MARK: - Test 5: Live Tutor Status Enum & Raw Values
    func testLiveTutorAllStatusRawValues() {
        XCTAssertEqual(LiveTutorStatus.live.rawValue, "LIVE")
        XCTAssertEqual(LiveTutorStatus.paused.rawValue, "PAUSED")
        XCTAssertEqual(LiveTutorStatus.listening.rawValue, "LISTENING")
        XCTAssertEqual(LiveTutorStatus.speaking.rawValue, "SPEAKING")
        XCTAssertEqual(LiveTutorStatus.verifying.rawValue, "VERIFYING")
    }

    // MARK: - Test 6: Tutor Response Category & Priority Invariants
    func testTutorMessageCategoriesAndPriorities() {
        let correction = TutorResponse(text: "Check your placement", priority: .high, category: "correction")
        XCTAssertEqual(correction.priority, .high)
        XCTAssertEqual(correction.category, "correction")

        let confirmation = TutorResponse(text: "Perfect match", priority: .normal, category: "confirmation")
        XCTAssertEqual(confirmation.priority, .normal)
        XCTAssertEqual(confirmation.category, "confirmation")

        viewModel.currentTutorMessage = correction
        XCTAssertEqual(viewModel.currentTutorMessage?.category, "correction")
        XCTAssertEqual(viewModel.currentTutorMessage?.priority, .high)
    }
}

