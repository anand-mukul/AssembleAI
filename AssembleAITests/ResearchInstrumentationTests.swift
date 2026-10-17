//
//  ResearchInstrumentationTests.swift
//  AssembleAI
//

import XCTest
@testable import AssembleAI

@MainActor
final class ResearchInstrumentationTests: XCTestCase {
    
    private var logger: ResearchLogger!
    private var sessionA: UUID!
    private var sessionB: UUID!
    private var projectID: UUID!
    private var step1ID: UUID!
    private var step2ID: UUID!
    
    override func setUp() async throws {
        try await super.setUp()
        logger = ResearchLogger()
        sessionA = UUID()
        sessionB = UUID()
        projectID = UUID()
        step1ID = UUID()
        step2ID = UUID()
    }
    
    override func tearDown() async throws {
        await logger.clearLogs()
        logger = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: Sequence Numbering & Event Logging
    func testStrictSequenceNumberingPerSession() async {
        let e1 = ResearchEvent(sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .sessionStarted)
        let e2 = ResearchEvent(sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .stepStarted)
        let e3 = ResearchEvent(sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .verificationCorrect)
        
        await logger.logEvent(e1)
        await logger.logEvent(e2)
        await logger.logEvent(e3)
        
        let sessionAEvents = await logger.fetchEvents(for: sessionA)
        XCTAssertEqual(sessionAEvents.count, 3)
        XCTAssertEqual(sessionAEvents[0].sequence, 1)
        XCTAssertEqual(sessionAEvents[1].sequence, 2)
        XCTAssertEqual(sessionAEvents[2].sequence, 3)
    }
    
    // MARK: - Test 2: Statistical Metrics Calculation
    func testStatisticalMetricsCalculation() async {
        let startTime = Date(timeIntervalSince1970: 1000)
        let step1Start = Date(timeIntervalSince1970: 1002)
        let incorrectTime = Date(timeIntervalSince1970: 1005)
        let correctTime = Date(timeIntervalSince1970: 1010)
        let step1End = Date(timeIntervalSince1970: 1012)
        let endTime = Date(timeIntervalSince1970: 1030)
        
        // Feed structured telemetry sequence
        await logger.logEvent(ResearchEvent(timestamp: startTime, sessionID: sessionA, projectID: projectID, mode: .liveTutor, eventType: .sessionStarted))
        await logger.logEvent(ResearchEvent(timestamp: step1Start, sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .stepStarted))
        await logger.logEvent(ResearchEvent(timestamp: incorrectTime, sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .verificationIncorrect, durationMilliseconds: 45))
        await logger.logEvent(ResearchEvent(timestamp: incorrectTime, sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .interventionTriggered, durationMilliseconds: 80))
        await logger.logEvent(ResearchEvent(timestamp: correctTime, sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .verificationCorrect, durationMilliseconds: 40))
        await logger.logEvent(ResearchEvent(timestamp: step1End, sessionID: sessionA, projectID: projectID, stepID: step1ID, mode: .liveTutor, eventType: .stepCompleted, durationMilliseconds: 150))
        await logger.logEvent(ResearchEvent(timestamp: endTime, sessionID: sessionA, projectID: projectID, mode: .liveTutor, eventType: .sessionCompleted))
        
        let metrics = await logger.calculateMetrics(for: sessionA)
        
        XCTAssertEqual(metrics.sessionID, sessionA)
        XCTAssertEqual(metrics.mode, .liveTutor)
        XCTAssertEqual(metrics.taskCompletionTimeSeconds, 30.0)
        XCTAssertEqual(metrics.completedStepsCount, 1)
        XCTAssertEqual(metrics.errorCount, 1)
        XCTAssertEqual(metrics.totalCorrectionTimeSeconds, 5.0, "Time from 1005 to 1010 = 5s correction time")
        XCTAssertEqual(metrics.interventionCount, 1)
        XCTAssertEqual(metrics.avgInterventionLatencyMs, 80)
        XCTAssertEqual(metrics.avgProgressionLatencyMs, 150)
    }
    
    // MARK: - Test 3: Session Isolation
    func testSessionIsolation() async {
        await logger.logEvent(ResearchEvent(sessionID: sessionA, projectID: projectID, mode: .liveTutor, eventType: .sessionStarted))
        await logger.logEvent(ResearchEvent(sessionID: sessionB, projectID: projectID, mode: .manual, eventType: .sessionStarted))
        
        let eventsA = await logger.fetchEvents(for: sessionA)
        let eventsB = await logger.fetchEvents(for: sessionB)
        
        XCTAssertEqual(eventsA.count, 1)
        XCTAssertEqual(eventsA[0].mode, .liveTutor)
        
        XCTAssertEqual(eventsB.count, 1)
        XCTAssertEqual(eventsB[0].mode, .manual)
    }
    
    // MARK: - Test 4: CSV Export Formatting & Privacy Verification
    func testCSVExportFormattingAndPrivacy() async {
        await logger.logEvent(ResearchEvent(
            sessionID: sessionA,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .stepStarted,
            metadata: ["testKey": "testVal"]
        ))
        
        let csv = await logger.exportCSV(for: sessionA)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        XCTAssertEqual(lines.count, 2, "Header + 1 event line")
        XCTAssertEqual(lines[0], ResearchEvent.csvHeader)
        XCTAssertTrue(lines[1].contains(sessionA.uuidString))
        XCTAssertTrue(lines[1].contains("liveTutor"))
        XCTAssertTrue(lines[1].contains("stepStarted"))
        
        // Assert zero pixel / audio / token leaks in telemetry
        XCTAssertFalse(csv.contains("CVPixelBuffer"))
        XCTAssertFalse(csv.contains("UIImage"))
        XCTAssertFalse(csv.contains("AVAudioPCMBuffer"))
        XCTAssertFalse(csv.contains("password"))
        XCTAssertFalse(csv.contains("token"))
    }
    
    // MARK: - Test 5: Explicit Session ID & Lifecycle Integration
    func testStartResearchSessionPreservesExplicitID() async {
        let customSessionID = UUID()
        let returnedID = await logger.startResearchSession(
            sessionID: customSessionID,
            projectID: projectID.uuidString,
            strategy: .lastNFrames,
            lastNFrames: 5,
            mode: .liveTutor
        )
        
        XCTAssertEqual(returnedID, customSessionID, "startResearchSession must reuse the explicit session ID")
        
        let config = await logger.getSessionConfig(for: customSessionID)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.projectID, projectID.uuidString)
        XCTAssertEqual(config?.strategy, .lastNFrames)
        XCTAssertEqual(config?.lastNFrames, 5)
        XCTAssertNotNil(config?.memoryBeforeMB)
    }
    
    // MARK: - Test 6: Frame Metrics Recording & Persistence
    func testFrameMetricsRecordingAndEndSession() async {
        let testSessionID = UUID()
        _ = await logger.startResearchSession(
            sessionID: testSessionID,
            projectID: projectID.uuidString,
            mode: .liveTutor
        )
        
        await logger.recordFrameProcessing(
            sessionID: testSessionID,
            received: 120,
            processed: 60,
            includedInContext: 5,
            dropped: 60
        )
        
        let metrics = await logger.endResearchSession(sessionID: testSessionID, externalBatteryCost: 0.04)
        
        XCTAssertEqual(metrics.sessionID, testSessionID)
        XCTAssertEqual(metrics.framesReceived, 120)
        XCTAssertEqual(metrics.framesProcessed, 60)
        XCTAssertEqual(metrics.framesIncludedInModelContext, 5)
        XCTAssertEqual(metrics.framesDropped, 60)
        XCTAssertEqual(metrics.batteryCost, 0.04)
    }
    
    // MARK: - Test 7: Token Consumption Telemetry Aggregation
    func testTokenTelemetryAggregation() async {
        let testSessionID = UUID()
        _ = await logger.startResearchSession(
            sessionID: testSessionID,
            projectID: projectID.uuidString,
            mode: .liveTutor
        )
        
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .assistantResponseGenerated,
            durationMilliseconds: 250,
            metadata: ["input_tokens": "85", "output_tokens": "22"]
        ))
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .assistantResponseGenerated,
            durationMilliseconds: 180,
            metadata: ["input_tokens": "110", "output_tokens": "35"]
        ))
        
        let metrics = await logger.calculateMetrics(for: testSessionID)
        
        XCTAssertEqual(metrics.totalInputTokens, 195)
        XCTAssertEqual(metrics.totalOutputTokens, 57)
        XCTAssertEqual(metrics.totalTokens, 252)
    }
    
    // MARK: - Test 8: Summary CSV 46-Column Completeness & Zero Blank Column Headers
    func testSummaryCSVCompletenessAndZeroBlankColumns() async {
        let testSessionID = UUID()
        _ = await logger.startResearchSession(
            sessionID: testSessionID,
            projectID: projectID.uuidString,
            mode: .liveTutor
        )
        
        await logger.recordFrameProcessing(
            sessionID: testSessionID,
            received: 50,
            processed: 25,
            includedInContext: 5,
            dropped: 25
        )
        
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .stepStarted
        ))
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .verificationCorrect,
            status: "correct"
        ))
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .stepCompleted
        ))
        
        _ = await logger.endResearchSession(sessionID: testSessionID, externalBatteryCost: 0.02)
        
        let summaryCSV = await logger.exportSummaryCSV()
        let lines = summaryCSV.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        XCTAssertGreaterThanOrEqual(lines.count, 2, "Must contain header and at least one session data row")
        let headerColumns = lines[0].components(separatedBy: ",")
        XCTAssertEqual(headerColumns.count, 46, "Summary CSV header must contain exactly 46 telemetry columns")
        XCTAssertTrue(headerColumns.contains("battery_level_delta"))
        XCTAssertTrue(headerColumns.contains("energy_cost"))
        XCTAssertTrue(headerColumns.contains("frames_received"))
        
        let dataColumns = lines[1].components(separatedBy: ",")
        XCTAssertEqual(dataColumns.count, 46, "Summary CSV data row must have matching 46 column values")
        
        // Assert tabularRowValues matches 46 elements
        let metrics = await logger.calculateMetrics(for: testSessionID)
        XCTAssertEqual(metrics.tabularRowValues.count, 46)
    }
    
    // MARK: - Test 9: Nominal Temporal Consistency Calculation
    func testNominalTemporalConsistencyIsOne() async {
        let testSessionID = UUID()
        _ = await logger.startResearchSession(
            sessionID: testSessionID,
            projectID: projectID.uuidString,
            mode: .liveTutor
        )
        
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step1ID,
            mode: .liveTutor,
            eventType: .verificationCorrect,
            status: "correct"
        ))
        await logger.logEvent(ResearchEvent(
            sessionID: testSessionID,
            projectID: projectID,
            stepID: step2ID,
            mode: .liveTutor,
            eventType: .verificationCorrect,
            status: "correct"
        ))
        
        let metrics = await logger.calculateMetrics(for: testSessionID)
        XCTAssertEqual(metrics.temporalConsistency, 1.0, "Sessions with zero errors and verified steps must report 1.0 nominal consistency")
    }
}
