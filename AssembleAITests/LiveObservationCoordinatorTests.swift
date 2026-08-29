//
//  LiveObservationCoordinatorTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class LiveObservationCoordinatorTests: XCTestCase {
    
    private var coordinator: LiveObservationCoordinator!
    private var step1: AssemblyStep!
    private var step2: AssemblyStep!
    private var step5: AssemblyStep!
    
    override func setUp() async throws {
        try await super.setUp()
        
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
        step5 = AssemblyStep(
            id: UUID(),
            projectId: projectID,
            stepOrder: 5,
            title: "Connect Ground Rail",
            instruction: "Connect jumper wire from GND rail to pin header"
        )
        
        // Zero duration debounce for direct unit testing
        coordinator = LiveObservationCoordinator(
            configuration: LiveObservationConfiguration(
                consecutiveObservationsRequired: 1,
                minimumStateDurationSeconds: 0.0,
                minimumEvidenceConfidence: 0.50
            )
        )
    }
    
    override func tearDown() async throws {
        coordinator = nil
        step1 = nil
        step2 = nil
        step5 = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: Correct State Verification
    func testCorrectStateVerification() async {
        let observation = VisualObservation(
            imageSize: CGSize(width: 1084, height: 812),
            detectedText: [
                DetectedText(text: "220 OHM RESISTOR R1", confidence: 0.95, boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1))
            ],
            regions: [
                DetectedRegion(label: "Row 10 to Row 15", confidence: 0.90, boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.2))
            ],
            processingTimeMs: 15.0
        )
        
        let result = await coordinator.process(observation: observation, for: step1)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .correct)
        XCTAssertTrue(result?.isCorrect == true)
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.75)
    }
    
    // MARK: - Test 2: Missing Component State Verification
    func testMissingComponentVerification() async {
        // Observation with capacitor marking instead of 220 ohm resistor for Step 1
        let observation = VisualObservation(
            imageSize: CGSize(width: 1084, height: 812),
            detectedText: [
                DetectedText(text: "Red LED", confidence: 0.90, boundingBox: .zero)
            ],
            regions: [
                DetectedRegion(label: "Slot", confidence: 0.80, boundingBox: .zero)
            ],
            processingTimeMs: 15.0
        )
        
        let result = await coordinator.process(observation: observation, for: step1)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .incorrect)
        XCTAssertFalse(result?.isCorrect == true)
    }
    
    // MARK: - Test 3: Wrong Connection Verification
    func testWrongConnectionVerification() async {
        // Step 5 expects GND Rail connection, but observation reports 5V Rail
        let observation = VisualObservation(
            imageSize: CGSize(width: 1084, height: 812),
            detectedText: [
                DetectedText(text: "5V Rail", confidence: 0.88, boundingBox: .zero)
            ],
            regions: [
                DetectedRegion(label: "Pin Header", confidence: 0.85, boundingBox: .zero)
            ],
            processingTimeMs: 15.0
        )
        
        let result = await coordinator.process(observation: observation, for: step5)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .incorrect)
    }
    
    // MARK: - Test 4: Insufficient Evidence Results in Uncertain (Not Incorrect)
    func testInsufficientVisualEvidenceYieldsUncertain() async {
        let blankObservation = VisualObservation(
            imageSize: CGSize(width: 1084, height: 812),
            detectedText: [],
            regions: [],
            processingTimeMs: 10.0
        )
        
        let result = await coordinator.process(observation: blankObservation, for: step1)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .uncertain, "Low visual evidence must result in .uncertain, never false .incorrect")
    }
    
    // MARK: - Test 5: Stability Window & Debounce
    func testStabilityWindowDebounce() async {
        // Coordinator requiring 2 consecutive observations
        let debouncedCoordinator = LiveObservationCoordinator(
            configuration: LiveObservationConfiguration(
                consecutiveObservationsRequired: 2,
                minimumStateDurationSeconds: 0.0,
                minimumEvidenceConfidence: 0.50
            )
        )
        
        let correctObservation = VisualObservation(
            imageSize: CGSize(width: 1084, height: 812),
            detectedText: [DetectedText(text: "220 OHM", confidence: 0.95, boundingBox: .zero)],
            regions: [DetectedRegion(label: "Slot", confidence: 0.90, boundingBox: .zero)],
            processingTimeMs: 10.0
        )
        
        // 1st Observation: Should NOT emit yet (count = 1 < 2)
        let firstResult = await debouncedCoordinator.process(observation: correctObservation, for: step1)
        XCTAssertNil(firstResult, "First observation should not pass stability window")
        
        // 2nd Observation: Confirmed stable! Should emit
        let secondResult = await debouncedCoordinator.process(observation: correctObservation, for: step1)
        XCTAssertNotNil(secondResult, "Second matching observation satisfies stability requirement")
        XCTAssertEqual(secondResult?.status, .correct)
        
        // 3rd Identical Observation: Duplicate protection suppresses emission
        let thirdResult = await debouncedCoordinator.process(observation: correctObservation, for: step1)
        XCTAssertNil(thirdResult, "Duplicate identical verification should be suppressed")
    }
    
    // MARK: - Test 6: Stale Step Result Protection
    func testStaleStepResultProtection() async {
        let (obsStream, obsContinuation) = AsyncStream.makeStream(of: VisualObservation.self)
        
        // Thread-safe mutable step provider
        final class StepBox: @unchecked Sendable {
            var step: AssemblyStep
            init(_ step: AssemblyStep) { self.step = step }
        }
        let box = StepBox(step1)
        
        let verificationStream = coordinator.liveVerificationStream(
            from: obsStream,
            stepProvider: { box.step }
        )
        
        var emittedResults: [VerificationResult] = []
        let consumerTask = Task {
            for await result in verificationStream {
                emittedResults.append(result)
            }
        }
        
        let correctObs = VisualObservation(
            imageSize: CGSize(width: 100, height: 100),
            detectedText: [DetectedText(text: "220 OHM", confidence: 0.95, boundingBox: .zero)],
            regions: [DetectedRegion(label: "Slot", confidence: 0.90, boundingBox: .zero)],
            processingTimeMs: 10.0
        )
        
        // Advance step before yielding observation
        box.step = step2 // Step 2 requires 100uF capacitor, but observation is 220 ohm resistor!
        obsContinuation.yield(correctObs)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        consumerTask.cancel()
        obsContinuation.finish()
        _ = await consumerTask.result
        
        // The observation was evaluated against step2 (not step1), correctly testing the active step
        XCTAssertEqual(emittedResults.count, 1)
        XCTAssertEqual(emittedResults.first?.status, .incorrect) // 220 ohm on Step 2 is incorrect
    }
    
    // MARK: - Test 7: Reset Clears Coordinator State
    func testResetClearsMetricsAndStability() async {
        let observation = VisualObservation(
            imageSize: CGSize(width: 100, height: 100),
            detectedText: [DetectedText(text: "220 OHM", confidence: 0.95, boundingBox: .zero)],
            regions: [DetectedRegion(label: "Slot", confidence: 0.90, boundingBox: .zero)],
            processingTimeMs: 10.0
        )
        
        _ = await coordinator.process(observation: observation, for: step1)
        
        var metrics = await coordinator.getMetrics()
        XCTAssertEqual(metrics.observationsReceived, 1)
        XCTAssertEqual(metrics.verificationsEmitted, 1)
        
        await coordinator.reset()
        
        metrics = await coordinator.getMetrics()
        XCTAssertEqual(metrics.observationsReceived, 0)
        XCTAssertEqual(metrics.verificationsEmitted, 0)
        XCTAssertNil(metrics.currentStableStatus)
    }
}
