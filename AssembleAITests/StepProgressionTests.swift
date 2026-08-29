//
//  StepProgressionTests.swift
//  AssembleAI
//

import XCTest
import CoreVideo
@testable import AssembleAI

@MainActor
final class StepProgressionTests: XCTestCase {
    
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
    
    // MARK: - Test 1: Step Progression from Step 1 to Step 2
    func testAutomaticStepProgressionOnVerification() async {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        XCTAssertEqual(viewModel.currentStep.stepOrder, 1)
        
        // Feed mock pixel buffer stream to start live tutor
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Mock Vision returning text matching expected state for Step 1
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0),
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0),
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0)
        ]
        
        viewModel.startLiveTutor(frameStream: stream)
        
        // Yield dummy CVPixelBuffer
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
            continuation.yield(buffer)
            continuation.yield(buffer)
        }
        
        // Allow live pipeline & debounced progression to complete
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        XCTAssertEqual(viewModel.currentStepIndex, 1, "Should automatically advance to Step 2")
        XCTAssertEqual(viewModel.currentStep.stepOrder, 2)
        XCTAssertTrue(viewModel.session.completedSteps.contains(0), "Step 0 must be in completedSteps")
        
        continuation.finish()
        viewModel.stopLiveTutor()
    }
    
    // MARK: - Test 2: Incorrect State Does NOT Progress
    func testIncorrectStateDoesNotProgress() async {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Mock Vision returning empty text (incomplete / incorrect)
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["Unrelated Item"], regions: [], processingTimeMs: 10.0)
        ]
        
        viewModel.startLiveTutor(frameStream: stream)
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertEqual(viewModel.currentStepIndex, 0, "Incorrect state must remain on Step 1")
        
        continuation.finish()
        viewModel.stopLiveTutor()
    }
    
    // MARK: - Test 3: Double-Advancement Protection
    func testDoubleAdvancementProtection() async {
        XCTAssertEqual(viewModel.currentStepIndex, 0)
        
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        // Send 10 identical matching observations in rapid succession
        mockVision.mockObservations = Array(
            repeating: VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["220", "R1", "Resistor"], regions: [], processingTimeMs: 10.0),
            count: 10
        )
        
        viewModel.startLiveTutor(frameStream: stream)
        
        if let buffer = createTestPixelBuffer() {
            for _ in 0..<10 {
                continuation.yield(buffer)
            }
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        XCTAssertEqual(viewModel.currentStepIndex, 1, "Must advance exactly once to Step 2, not skip to Step 3")
        
        continuation.finish()
        viewModel.stopLiveTutor()
    }
    
    // MARK: - Test 4: Final Step Completes Session
    func testFinalStepCompletion() async {
        // Start on Step 2 (last step: index 1)
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStepIndex, 1)
        
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        
        mockVision.mockObservations = [
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["100uF", "C2", "Capacitor"], regions: [], processingTimeMs: 10.0),
            VisualObservation(imageSize: CGSize(width: 800, height: 600), detectedText: ["100uF", "C2", "Capacitor"], regions: [], processingTimeMs: 10.0)
        ]
        
        viewModel.startLiveTutor(frameStream: stream)
        
        if let buffer = createTestPixelBuffer() {
            continuation.yield(buffer)
            continuation.yield(buffer)
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        XCTAssertEqual(viewModel.phase, .completed, "Final step completion must transition phase to .completed")
        XCTAssertNotNil(viewModel.session.endedAt)
        
        continuation.finish()
        viewModel.stopLiveTutor()
    }
    
    // MARK: - Test 5: Voice Question "Repeat Instruction" on Active Step
    func testVoiceRepeatInstructionActiveStep() async {
        XCTAssertEqual(viewModel.currentStep.stepOrder, 1)
        
        viewModel.toggleVoiceInput()
        mockVoiceInput.simulateSpokenTranscript("repeat that", isFinal: true)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(mockVoiceOutput.spokenResponses.count, 1)
        XCTAssertTrue(mockVoiceOutput.spokenResponses.first?.text.contains("Insert 220Ω Resistor") == true)
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
