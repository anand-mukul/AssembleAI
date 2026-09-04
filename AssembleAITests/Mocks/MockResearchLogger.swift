//
//  MockResearchLogger.swift
//  AssembleAITests
//

import Foundation
@testable import AssembleAI

/// Actor-isolated mock research logger for unit and integration testing.
actor MockResearchLogger: ResearchLogging {
    private(set) var loggedEvents: [ResearchEvent] = []
    private var mockSessions: [UUID: ResearchSessionConfig] = [:]
    
    init() {}
    
    func logEvent(_ event: ResearchEvent) async {
        loggedEvents.append(event)
    }
    
    func fetchEvents(for sessionID: UUID) async -> [ResearchEvent] {
        return loggedEvents.filter { $0.sessionID == sessionID }
    }
    
    func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics {
        let sessionEvents = loggedEvents.filter { $0.sessionID == sessionID }
        return ResearchSessionMetrics(
            sessionID: sessionID,
            mode: sessionEvents.first?.mode ?? .liveTutor,
            taskCompletionTimeSeconds: 120.0,
            completedStepsCount: 2,
            totalVerificationAttempts: 5,
            errorCount: 1,
            uncertainCount: 1,
            totalCorrectionTimeSeconds: 15.0,
            interventionCount: 2,
            userQuestionCount: 1,
            avgInterventionLatencyMs: 80,
            avgModelLatencyMs: 320,
            avgSpeechLatencyMs: 65,
            avgProgressionLatencyMs: 450
        )
    }
    
    func exportCSV(for sessionID: UUID? = nil) async -> String {
        let target = sessionID != nil ? loggedEvents.filter { $0.sessionID == sessionID } : loggedEvents
        var csv = ResearchEvent.csvHeader + "\n"
        for event in target {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    func clearLogs() async {
        loggedEvents.removeAll()
        mockSessions.removeAll()
    }
    
    func startResearchSession(
        projectID: String,
        strategy: VisualHistoryStrategy,
        lastNFrames: Int?,
        mode: InteractionMode
    ) async -> UUID {
        let sid = UUID()
        let config = ResearchSessionConfig(
            id: sid,
            projectID: projectID,
            interactionMode: mode,
            strategy: strategy,
            lastNFrames: lastNFrames,
            startedAt: Date(),
            endedAt: nil,
            schemaVersion: ResearchLogger.researchSchemaVersion,
            osVersion: "iOS 26.5",
            deviceModel: "MockDevice",
            memoryBeforeMB: 42.0,
            memoryAfterMB: nil,
            peakMemoryMB: 42.0,
            batteryCost: nil,
            batteryLevelStart: nil,
            batteryLevelEnd: nil,
            framesReceived: 0,
            framesProcessed: 0,
            framesIncludedInModelContext: 0,
            framesDropped: 0
        )
        mockSessions[sid] = config
        return sid
    }
    
    func endResearchSession(
        sessionID: UUID,
        externalBatteryCost: Double?
    ) async -> ResearchSessionMetrics {
        return await calculateMetrics(for: sessionID)
    }
    
    func getSessionConfig(for sessionID: UUID) async -> ResearchSessionConfig? {
        return mockSessions[sessionID]
    }
    
    func fetchAllSessions() async -> [ResearchSessionConfig] {
        return Array(mockSessions.values)
    }
    
    func getTelemetryStats() async -> (sessionCount: Int, eventCount: Int) {
        let knownIDs = Set(mockSessions.keys)
        let eventIDs = Set(loggedEvents.map(\.sessionID))
        return (knownIDs.union(eventIDs).count, loggedEvents.count)
    }
    
    func exportCSVFile(for sessionID: UUID?) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_export.csv")
        try await exportCSV(for: sessionID).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func exportJSON(for sessionID: UUID?) async throws -> String {
        return "[]"
    }
    
    func exportJSONFile(for sessionID: UUID?) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_export.json")
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func exportSummaryCSV() async -> String {
        return ResearchSessionMetrics.summaryCSVHeader + "\n"
    }
    
    func exportSummaryCSVFile() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_summary.csv")
        try await exportSummaryCSV().write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
