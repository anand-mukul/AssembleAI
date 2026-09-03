//
//  MistakeAnalyticsServiceTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class MistakeAnalyticsServiceTests: XCTestCase {
    
    func testRecordAndSummarizeMistakes() async {
        let analytics = MistakeAnalyticsService()
        let sessionId = UUID()
        
        // Record Step 1: Smooth
        await analytics.recordStep(
            sessionId: sessionId,
            stepOrder: 1,
            stepTitle: "Insert Resistor",
            durationSeconds: 25.0,
            attemptsCount: 1,
            encounteredMistakes: [],
            wasSuccessful: true
        )
        
        // Record Step 2: Friction with Row 14 misplacement
        await analytics.recordStep(
            sessionId: sessionId,
            stepOrder: 2,
            stepTitle: "Insert Capacitor",
            durationSeconds: 85.0,
            attemptsCount: 3,
            encounteredMistakes: ["Row 14 bridging", "Reversed polarity"],
            wasSuccessful: true
        )
        
        let summary = await analytics.computeAnalyticsSummary()
        
        XCTAssertEqual(summary.totalSessions, 1)
        XCTAssertEqual(summary.completionRate, 1.0)
        XCTAssertEqual(summary.highestFrictionStepOrder, 2)
        XCTAssertEqual(summary.topMistakes.count, 2)
        XCTAssertTrue(summary.topMistakes.contains(where: { $0.mistake == "Row 14 bridging" }))
    }
    
    func testEmptyAnalyticsSummary() async {
        let analytics = MistakeAnalyticsService()
        let summary = await analytics.computeAnalyticsSummary()
        
        XCTAssertEqual(summary.totalSessions, 0)
        XCTAssertEqual(summary.completionRate, 0.0)
        XCTAssertNil(summary.highestFrictionStepOrder)
        XCTAssertTrue(summary.topMistakes.isEmpty)
    }
}
