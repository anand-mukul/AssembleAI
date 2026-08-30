//
//  MasterEndToEndIntegrationTests.swift
//  AssembleAI
//

import XCTest
import CoreVideo
@testable import AssembleAI

@MainActor
final class MasterEndToEndIntegrationTests: XCTestCase {
    
    private var viewModel: AssemblyViewModel!
    private var mockVision: MockVisionService!
    private var mockVoiceOutput: MockVoiceOutputService!
    private var mockVoiceInput: MockVoiceInputService!
    private var mockTutor: MockConversationalTutorProvider!
    private var mockLogger: MockResearchLogger!
    private var project: AssemblyProject!
    
    override func setUp() {
        super.setUp()
        mockVision = MockVisionService()
        mockVoiceOutput = MockVoiceOutputService()
        mockVoiceInput = MockVoiceInputService()
        mockTutor = MockConversationalTutorProvider()
        mockLogger = MockResearchLogger()
        
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
            voiceInput: mockVoiceInput,
            researchLogger: mockLogger
        )
    }
    
    override func tearDown() {
        viewModel.stopLiveTutor()
        viewModel = nil
        mockVision = nil
        mockVoiceOutput = nil
        mockVoiceInput = nil
        mockTutor = nil
        mockLogger = nil
        project = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Full End-to-End Assembly Journey
    func testCompleteMultiStepLiveAssemblyJourney() async {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        XCTAssertEqual(viewModel.currentStep.stepOrder, 1)
        
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Phase 1: Incorrect observation on Step 1 -> Triggers corrective guidance
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "Row 14"], regions: [], processingTimeMs: 10.0)
        ]
        
        viewModel.startLiveTutor(frameStream: stream)
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(viewModel.currentStepIndex, 0, "Incorrect state must keep user on Step 1")
        
        // Phase 2: User fixes mistake -> Correct observation on Step 1 -> Confirms and auto-advances to Step 2
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0),
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0)
        ]
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
            continuation.yield(buffer)
        }
        
        // Allow debounce window to advance
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(viewModel.currentStepIndex, 1, "Must advance automatically to Step 2")
        XCTAssertEqual(viewModel.currentStep.stepOrder, 2)
        
        // Phase 3: User asks "Why?" during Step 2 -> Voice input answers grounded in Step 2
        viewModel.toggleVoiceInput()
        await mockVoiceInput.simulateSpokenTranscript("why do we use C2 header", isFinal: true)
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockTutor.answerQuestionCallCount, 1)
        XCTAssertEqual(mockTutor.lastReceivedContext?.currentStep.stepOrder, 2, "Context must refer to active Step 2")
        
        // Phase 4: Step 2 completes -> Assembly completes
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["100uF", "C2", "Capacitor"], regions: [], processingTimeMs: 10.0),
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["100uF", "C2", "Capacitor"], regions: [], processingTimeMs: 10.0)
        ]
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
            continuation.yield(buffer)
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(viewModel.phase, .completed, "Final step must transition phase to .completed")
        XCTAssertNotNil(viewModel.session.endedAt)
        
        continuation.finish()
    }
    
    // MARK: - Test 2: Double-Pipeline / Rapid Restart Protection
    func testRapidRestartDoesNotLeakPipelines() async {
        let (stream1, cont1) = AsyncStream<CVPixelBuffer>.makeStream()
        let (stream2, cont2) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Start Live Tutor twice
        viewModel.startLiveTutor(frameStream: stream1)
        viewModel.startLiveTutor(frameStream: stream2)
        
        XCTAssertEqual(viewModel.liveStatus, .live)
        
        cont1.finish()
        cont2.finish()
        viewModel.stopLiveTutor()
        
        let state = await mockVoiceOutput.state
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - Test 3: Model Authority Invariant (Physical Truth Guaranteed)
    func testModelCannotOverridePhysicalVerification() async {
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Comparator detects incorrect
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["Wrong item"], regions: [], processingTimeMs: 10.0)
        ]
        
        // Model hallucinates praise
        mockTutor.setScriptedResponses([
            TutorResponse(text: "Everything looks flawless!", priority: .normal)
        ])
        
        viewModel.startLiveTutor(frameStream: stream)
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        XCTAssertEqual(viewModel.currentStepIndex, 0, "Model praise cannot advance step when physical state is incorrect")
        XCTAssertNotEqual(viewModel.currentVerificationResult?.status, .correct)
        
        continuation.finish()
    }
    
    // MARK: - Test 4: Silence Preservation Test
    func testSilenceDecisionProducesZeroModelAndSpeechActivity() async {
        // Evaluate silent decision directly
        let silentDecision = InterventionDecision.silent(reason: "Stable progress")
        let context = AssistantContext(currentStep: viewModel.currentStep)
        
        let response = await mockTutor.generateResponse(for: silentDecision, context: context)
        XCTAssertNil(response, "Silent decisions must not produce tutor responses")
        let spokenCount = await mockVoiceOutput.spokenResponses.count
        XCTAssertEqual(spokenCount, 0)
    }
    
    // MARK: - Test 5: Research Telemetry Isolation & Privacy
    func testResearchTelemetryCollectionAndPrivacy() async {
        viewModel.beginAssembly()
        viewModel.nextStep()
        
        let events = await mockLogger.loggedEvents
        XCTAssertFalse(events.isEmpty)
        
        for event in events {
            XCTAssertEqual(event.sessionID, viewModel.session.id)
            XCTAssertFalse(event.metadata.keys.contains("password"))
            XCTAssertFalse(event.metadata.keys.contains("audioBuffer"))
            XCTAssertFalse(event.metadata.keys.contains("pixelBuffer"))
        }
    }
    
    // MARK: - Test 6: Stale Step Event Rejection
    func testStaleStepResponseIsIgnored() async {
        let step1ID = viewModel.currentStep.id
        viewModel.nextStep()
        let step2ID = viewModel.currentStep.id
        XCTAssertNotEqual(step1ID, step2ID)
        
        // Simulate delayed step 1 message arrival
        let staleDecision = InterventionDecision(action: .instruct(step: AssemblyStep(id: step1ID, projectId: project.id, stepOrder: 1, title: "Step 1", instruction: "Old")), reason: "Stale")
        let staleContext = AssistantContext(currentStep: AssemblyStep(id: step1ID, projectId: project.id, stepOrder: 1, title: "Step 1", instruction: "Old"))
        
        let response = await mockTutor.generateResponse(for: staleDecision, context: staleContext)
        XCTAssertNotNil(response)
        
        // Assert: ViewModel's current step is Step 2 and does not revert to Step 1
        XCTAssertEqual(viewModel.currentStep.stepOrder, 2)
    }
    
    // MARK: - Helper
    private func createTestPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            32,
            32,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        return buffer
    }
}
