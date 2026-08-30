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
    
    override func setUp() async {
        await super.setUp()
        logger = ResearchLogger()
        sessionA = UUID()
        sessionB = UUID()
        projectID = UUID()
        step1ID = UUID()
        step2ID = UUID()
    }
    
    override func tearDown() async {
        await logger.clearLogs()
        logger = nil
        await super.tearDown()
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
}
