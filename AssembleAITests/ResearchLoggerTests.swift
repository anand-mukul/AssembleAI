//
//  ResearchLoggerTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class ResearchLoggerTests: XCTestCase {
    
    private var logger: ResearchLogger!
    private let sampleSessionID = UUID()
    private let sampleProjectID = UUID()
    private let sampleStepID = UUID()
    
    override func setUp() {
        super.setUp()
        logger = ResearchLogger()
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Event Logging & Metrics Calculation
    func testEventLoggingAndMetricsCalculation() async {
        let startEvent = ResearchEvent(
            sessionID: sampleSessionID,
            projectID: sampleProjectID,
            stepID: sampleStepID,
            eventType: .sessionStarted
        )
        let ver1 = ResearchEvent(
            sessionID: sampleSessionID,
            projectID: sampleProjectID,
            stepID: sampleStepID,
            eventType: .verificationCompleted,
            durationMilliseconds: 140,
            attemptNumber: 1,
            verificationStatus: "incorrect"
        )
        let ver2 = ResearchEvent(
            sessionID: sampleSessionID,
            projectID: sampleProjectID,
            stepID: sampleStepID,
            eventType: .verificationCompleted,
            durationMilliseconds: 120,
            attemptNumber: 2,
            verificationStatus: "correct"
        )
        let stepComp = ResearchEvent(
            sessionID: sampleSessionID,
            projectID: sampleProjectID,
            stepID: sampleStepID,
            eventType: .stepCompleted
        )
        
        await logger.logEvent(startEvent)
        await logger.logEvent(ver1)
        await logger.logEvent(ver2)
        await logger.logEvent(stepComp)
        
        let metrics = await logger.calculateMetrics(for: sampleSessionID)
        
        XCTAssertEqual(metrics.sessionID, sampleSessionID)
        XCTAssertEqual(metrics.completedStepsCount, 1)
        XCTAssertEqual(metrics.totalAttempts, 2)
        XCTAssertEqual(metrics.errorCount, 1)
        XCTAssertEqual(metrics.avgVerificationLatencyMs, 130)
    }
    
    // MARK: - Test 2: CSV Export Formatting
    func testCSVExportFormatting() async {
        let event = ResearchEvent(
            sessionID: sampleSessionID,
            projectID: sampleProjectID,
            stepID: sampleStepID,
            eventType: .verificationCompleted,
            durationMilliseconds: 150,
            attemptNumber: 1,
            verificationStatus: "correct"
        )
        
        await logger.logEvent(event)
        let csv = await logger.exportCSV()
        
        XCTAssertTrue(csv.contains("event_id,timestamp,session_id"))
        XCTAssertTrue(csv.contains(sampleSessionID.uuidString))
        XCTAssertTrue(csv.contains("verificationCompleted"))
        XCTAssertTrue(csv.contains("correct"))
    }
}
