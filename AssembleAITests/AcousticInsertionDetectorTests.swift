//
//  AcousticInsertionDetectorTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class AcousticInsertionDetectorTests: XCTestCase {
    
    private var detector: AcousticInsertionDetector!
    
    override func setUp() async throws {
        try await super.setUp()
        detector = AcousticInsertionDetector()
        await detector.startMonitoring()
    }
    
    override func tearDown() async throws {
        await detector.stopMonitoring()
        detector = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: Monitoring Lifecycle
    func testMonitoringLifecycle() async {
        let isMonitoring = await detector.isCurrentlyMonitoring()
        XCTAssertTrue(isMonitoring)
        
        await detector.stopMonitoring()
        let isStopped = await detector.isCurrentlyMonitoring()
        XCTAssertFalse(isStopped)
    }
    
    // MARK: - Test 2: Low Amplitude Below Threshold Ignored
    func testLowAmplitudeIgnored() async {
        // Low amplitude (0.01 = -40 dBFS), below -24 dBFS threshold
        let event = await detector.processAudioBuffer(peakAmplitude: 0.01, rmsAmplitude: 0.005)
        XCTAssertNil(event)
    }
    
    // MARK: - Test 3: Low Crest Factor Ignored (Continuous Noise)
    func testLowCrestFactorIgnored() async {
        // Continuous loud hum (e.g. fan or air conditioner): high RMS, low crest factor
        let event = await detector.processAudioBuffer(peakAmplitude: 0.5, rmsAmplitude: 0.4)
        XCTAssertNil(event, "Continuous sound with low crest factor should not trigger mechanical click detection")
    }
    
    // MARK: - Test 4: Breadboard Spring Snap Detection
    func testBreadboardSpringSnapDetection() async {
        // High crest factor (> 4.0) and high peak (> -15 dBFS)
        // 0.70 / 0.12 = 5.83 crest factor, 20*log10(0.70) = -3.1 dBFS
        let event = await detector.processAudioBuffer(peakAmplitude: 0.70, rmsAmplitude: 0.12)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .breadboardSpringSnap)
        XCTAssertGreaterThan(event?.confidence ?? 0, 0.80)
    }
    
    // MARK: - Test 5: Tactile Switch Click Detection
    func testTactileSwitchClickDetection() async {
        // Moderate crest factor (> 3.0)
        // 0.45 / 0.13 = 3.46 crest factor, 20*log10(0.45) = -6.9 dBFS
        let event = await detector.processAudioBuffer(peakAmplitude: 0.45, rmsAmplitude: 0.13)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, .tactileSwitchClick)
    }
    
    // MARK: - Test 6: Temporal Correlation with Hand Pose Event
    func testTemporalCorrelationNearTimestamp() async {
        let now = CFAbsoluteTimeGetCurrent()
        let manualEvent = AcousticInsertionDetector.AcousticEvent(
            type: .breadboardSpringSnap,
            timestamp: now - 0.2, // 200ms ago
            confidence: 0.92,
            peakDecibels: -4.0
        )
        await detector.recordEvent(manualEvent)
        
        // Hand withdrawal detected right now -> query for acoustic event near now
        let (foundRecent, matchedEvent) = await detector.hasInsertionEventNear(timestamp: now, toleranceSeconds: 0.5)
        XCTAssertTrue(foundRecent)
        XCTAssertEqual(matchedEvent?.type, .breadboardSpringSnap)
        
        // Query for event from 10 seconds ago -> should return false
        let (foundOld, _) = await detector.hasInsertionEventNear(timestamp: now - 10.0, toleranceSeconds: 0.5)
        XCTAssertFalse(foundOld)
    }
    
    // MARK: - Test 7: Max Stored Events Eviction
    func testMaxStoredEventsEviction() async {
        let now = CFAbsoluteTimeGetCurrent()
        for i in 0..<30 {
            let event = AcousticInsertionDetector.AcousticEvent(
                type: .generalTransientClick,
                timestamp: now + Double(i) * 0.01,
                confidence: 0.7,
                peakDecibels: -10.0
            )
            await detector.recordEvent(event)
        }
        
        let recent = await detector.eventsInLast(seconds: 10.0)
        XCTAssertLessThanOrEqual(recent.count, 20, "Should enforce ring buffer max limit of 20 stored events")
    }
    
    // MARK: - Test 8: Clear History
    func testClearHistory() async {
        let event = AcousticInsertionDetector.AcousticEvent(
            type: .tactileSwitchClick,
            timestamp: CFAbsoluteTimeGetCurrent(),
            confidence: 0.8,
            peakDecibels: -8.0
        )
        await detector.recordEvent(event)
        
        var recent = await detector.eventsInLast(seconds: 5.0)
        XCTAssertEqual(recent.count, 1)
        
        await detector.clearHistory()
        recent = await detector.eventsInLast(seconds: 5.0)
        XCTAssertEqual(recent.count, 0)
    }
}
