//
//  ResearchLogger.swift
//  AssembleAI
//

import Foundation

// MARK: - Research Session Metrics

/// Comprehensive statistical metrics calculated for an experimental evaluation session.
nonisolated struct ResearchSessionMetrics: Sendable, Equatable {
    let sessionID: UUID
    let mode: InteractionMode
    let taskCompletionTimeSeconds: Double
    let completedStepsCount: Int
    let totalVerificationAttempts: Int
    let errorCount: Int
    let uncertainCount: Int
    let totalCorrectionTimeSeconds: Double
    let interventionCount: Int
    let userQuestionCount: Int
    let avgInterventionLatencyMs: Int
    let avgModelLatencyMs: Int
    let avgSpeechLatencyMs: Int
    let avgProgressionLatencyMs: Int
    let avgVerificationLatencyMs: Int
    
    var durationSeconds: Int { Int(taskCompletionTimeSeconds) }
    var totalAttempts: Int { totalVerificationAttempts }
    var avgGuidanceLatencyMs: Int { avgModelLatencyMs }
    
    init(
        sessionID: UUID,
        mode: InteractionMode,
        taskCompletionTimeSeconds: Double,
        completedStepsCount: Int,
        totalVerificationAttempts: Int,
        errorCount: Int,
        uncertainCount: Int,
        totalCorrectionTimeSeconds: Double,
        interventionCount: Int,
        userQuestionCount: Int,
        avgInterventionLatencyMs: Int,
        avgModelLatencyMs: Int,
        avgSpeechLatencyMs: Int,
        avgProgressionLatencyMs: Int,
        avgVerificationLatencyMs: Int? = nil
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.taskCompletionTimeSeconds = taskCompletionTimeSeconds
        self.completedStepsCount = completedStepsCount
        self.totalVerificationAttempts = totalVerificationAttempts
        self.errorCount = errorCount
        self.uncertainCount = uncertainCount
        self.totalCorrectionTimeSeconds = totalCorrectionTimeSeconds
        self.interventionCount = interventionCount
        self.userQuestionCount = userQuestionCount
        self.avgInterventionLatencyMs = avgInterventionLatencyMs
        self.avgModelLatencyMs = avgModelLatencyMs
        self.avgSpeechLatencyMs = avgSpeechLatencyMs
        self.avgProgressionLatencyMs = avgProgressionLatencyMs
        self.avgVerificationLatencyMs = avgVerificationLatencyMs ?? avgInterventionLatencyMs
    }
}

// MARK: - Research Logging Protocol

/// Abstract interface for recording research telemetry events.
protocol ResearchLogging: Sendable {
    func logEvent(_ event: ResearchEvent) async
    func fetchEvents(for sessionID: UUID) async -> [ResearchEvent]
    func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics
    func exportCSV(for sessionID: UUID?) async -> String
    func clearLogs() async
}

// MARK: - Concrete Research Logger Actor

/// Thread-safe local research logger capturing pseudonymous session metrics, monotonic sequencing, and CSV export.
actor ResearchLogger: ResearchLogging {
    static let shared = ResearchLogger()
    
    private var events: [ResearchEvent] = []
    private var sessionSequences: [UUID: Int] = [:]
    
    init() {}
    
    /// Records a research telemetry event with automatic per-session sequence numbering.
    func logEvent(_ event: ResearchEvent) {
        let seq = (sessionSequences[event.sessionID] ?? 0) + 1
        sessionSequences[event.sessionID] = seq
        
        let sequencedEvent = ResearchEvent(
            id: event.id,
            sequence: seq,
            timestamp: event.timestamp,
            sessionID: event.sessionID,
            projectID: event.projectID,
            stepID: event.stepID,
            mode: event.mode,
            eventType: event.eventType,
            durationMilliseconds: event.durationMilliseconds,
            verificationStatus: event.verificationStatus,
            metadata: event.metadata
        )
        events.append(sequencedEvent)
    }
    
    /// Returns all logged events for a given session.
    func fetchEvents(for sessionID: UUID) -> [ResearchEvent] {
        return events.filter { $0.sessionID == sessionID }
    }
    
    /// Calculates aggregate research metrics for an experimental session.
    func calculateMetrics(for sessionID: UUID) -> ResearchSessionMetrics {
        let sessionEvents = fetchEvents(for: sessionID)
        let mode = sessionEvents.first?.mode ?? .liveTutor
        
        // 1. Task Completion Time
        let startEvent = sessionEvents.first { $0.eventType == .sessionStarted }
        let endEvent = sessionEvents.last { $0.eventType == .sessionCompleted || $0.eventType == .stepCompleted }
        
        let totalTime: Double
        if let start = startEvent, let end = endEvent {
            totalTime = max(0.0, end.timestamp.timeIntervalSince(start.timestamp))
        } else {
            totalTime = 0.0
        }
        
        // 2. Step Completion Count
        let completedSteps = sessionEvents.filter { $0.eventType == .stepCompleted }.count
        
        // 3. Verification Counts & Latency
        let correctEvents = sessionEvents.filter { $0.eventType == .verificationCorrect || ($0.eventType == .verificationCompleted && $0.verificationStatus == "correct") }
        let incorrectEvents = sessionEvents.filter { $0.eventType == .verificationIncorrect || ($0.eventType == .verificationCompleted && $0.verificationStatus == "incorrect") }
        let uncertainEvents = sessionEvents.filter { $0.eventType == .verificationUncertain || ($0.eventType == .verificationCompleted && $0.verificationStatus == "uncertain") }
        let otherVerEvents = sessionEvents.filter { $0.eventType == .verificationCompleted && $0.verificationStatus != "correct" && $0.verificationStatus != "incorrect" && $0.verificationStatus != "uncertain" }
        let totalVerifications = correctEvents.count + incorrectEvents.count + uncertainEvents.count + otherVerEvents.count
        
        let allVerEvents = correctEvents + incorrectEvents + uncertainEvents + otherVerEvents
        let verLatencies = allVerEvents.compactMap(\.durationMilliseconds)
        let avgVerLatency = verLatencies.isEmpty ? 0 : verLatencies.reduce(0, +) / verLatencies.count
        
        // 4. Correction Time Calculation (Time from first incorrect to correct per step)
        var totalCorrectionTime: Double = 0.0
        let stepIDs = Set(sessionEvents.compactMap(\.stepID))
        for stepID in stepIDs {
            let stepEvents = sessionEvents.filter { $0.stepID == stepID }
            if let firstIncorrect = stepEvents.first(where: { $0.eventType == .verificationIncorrect || ($0.eventType == .verificationCompleted && $0.verificationStatus == "incorrect") }),
               let firstCorrectAfter = stepEvents.first(where: { ($0.eventType == .verificationCorrect || ($0.eventType == .verificationCompleted && $0.verificationStatus == "correct")) && $0.timestamp >= firstIncorrect.timestamp }) {
                totalCorrectionTime += max(0.0, firstCorrectAfter.timestamp.timeIntervalSince(firstIncorrect.timestamp))
            }
        }
        
        // 5. Interventions & Questions
        let interventionEvents = sessionEvents.filter { $0.eventType == .interventionTriggered }
        let userVoiceEvents = sessionEvents.filter { $0.eventType == .userVoiceCompleted }
        
        // 6. Latency Averages
        let modelLatencies = sessionEvents.filter { $0.eventType == .assistantResponseGenerated }.compactMap(\.durationMilliseconds)
        let avgModelLatency = modelLatencies.isEmpty ? 0 : modelLatencies.reduce(0, +) / modelLatencies.count
        
        let speechLatencies = sessionEvents.filter { $0.eventType == .assistantSpeechStarted }.compactMap(\.durationMilliseconds)
        let avgSpeechLatency = speechLatencies.isEmpty ? 0 : speechLatencies.reduce(0, +) / speechLatencies.count
        
        let interventionLatencies = interventionEvents.compactMap(\.durationMilliseconds)
        let avgInterventionLatency = interventionLatencies.isEmpty ? 0 : interventionLatencies.reduce(0, +) / interventionLatencies.count
        
        let progressionLatencies = sessionEvents.filter { $0.eventType == .stepCompleted }.compactMap(\.durationMilliseconds)
        let avgProgressionLatency = progressionLatencies.isEmpty ? 0 : progressionLatencies.reduce(0, +) / progressionLatencies.count
        
        return ResearchSessionMetrics(
            sessionID: sessionID,
            mode: mode,
            taskCompletionTimeSeconds: totalTime,
            completedStepsCount: completedSteps,
            totalVerificationAttempts: totalVerifications,
            errorCount: incorrectEvents.count,
            uncertainCount: uncertainEvents.count,
            totalCorrectionTimeSeconds: totalCorrectionTime,
            interventionCount: interventionEvents.count,
            userQuestionCount: userVoiceEvents.count,
            avgInterventionLatencyMs: avgInterventionLatency,
            avgModelLatencyMs: avgModelLatency,
            avgSpeechLatencyMs: avgSpeechLatency,
            avgProgressionLatencyMs: avgProgressionLatency,
            avgVerificationLatencyMs: avgVerLatency
        )
    }
    
    /// Exports recorded research events as an anonymized RFC 4180 CSV string.
    func exportCSV(for sessionID: UUID? = nil) -> String {
        let targetEvents = sessionID != nil ? events.filter { $0.sessionID == sessionID } : events
        var csv = ResearchEvent.csvHeader + "\n"
        for event in targetEvents {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    /// Clears all stored research event logs.
    func clearLogs() {
        events.removeAll()
        sessionSequences.removeAll()
    }
}

// MARK: - Mock Research Logger

/// Actor-isolated mock research logger for unit testing.
actor MockResearchLogger: ResearchLogging {
    private(set) var loggedEvents: [ResearchEvent] = []
    
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
    
    func exportCSV(for sessionID: UUID?) async -> String {
        let target = sessionID != nil ? loggedEvents.filter { $0.sessionID == sessionID } : loggedEvents
        var csv = ResearchEvent.csvHeader + "\n"
        for event in target {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    func clearLogs() async {
        loggedEvents.removeAll()
    }
}
