//
//  ResearchLogger.swift
//  AssembleAI
//

import Foundation

// MARK: - Research Session Metrics

/// Comprehensive statistical metrics calculated for an experimental evaluation session.
public struct ResearchSessionMetrics: Sendable, Equatable {
    public let sessionID: UUID
    public let mode: InteractionMode
    public let taskCompletionTimeSeconds: Double
    public let completedStepsCount: Int
    public let totalVerificationAttempts: Int
    public let errorCount: Int
    public let uncertainCount: Int
    public let totalCorrectionTimeSeconds: Double
    public let interventionCount: Int
    public let userQuestionCount: Int
    public let avgInterventionLatencyMs: Int
    public let avgModelLatencyMs: Int
    public let avgSpeechLatencyMs: Int
    public let avgProgressionLatencyMs: Int
}

// MARK: - Research Logging Protocol

/// Abstract interface for recording research telemetry events.
public protocol ResearchLogging: Sendable {
    func logEvent(_ event: ResearchEvent) async
    func fetchEvents(for sessionID: UUID) async -> [ResearchEvent]
    func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics
    func exportCSV(for sessionID: UUID?) async -> String
    func clearLogs() async
}

// MARK: - Concrete Research Logger Actor

/// Thread-safe local research logger capturing pseudonymous session metrics, monotonic sequencing, and CSV export.
public actor ResearchLogger: ResearchLogging {
    public static let shared = ResearchLogger()
    
    private var events: [ResearchEvent] = []
    private var sessionSequences: [UUID: Int] = [:]
    
    public init() {}
    
    /// Records a research telemetry event with automatic per-session sequence numbering.
    public func logEvent(_ event: ResearchEvent) {
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
    public func fetchEvents(for sessionID: UUID) -> [ResearchEvent] {
        return events.filter { $0.sessionID == sessionID }
    }
    
    /// Calculates aggregate research metrics for an experimental session.
    public func calculateMetrics(for sessionID: UUID) -> ResearchSessionMetrics {
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
        
        // 3. Verification Counts
        let correctEvents = sessionEvents.filter { $0.eventType == .verificationCorrect }
        let incorrectEvents = sessionEvents.filter { $0.eventType == .verificationIncorrect }
        let uncertainEvents = sessionEvents.filter { $0.eventType == .verificationUncertain }
        let totalVerifications = correctEvents.count + incorrectEvents.count + uncertainEvents.count
        
        // 4. Correction Time Calculation (Time from first incorrect to correct per step)
        var totalCorrectionTime: Double = 0.0
        let stepIDs = Set(sessionEvents.compactMap(\.stepID))
        for stepID in stepIDs {
            let stepEvents = sessionEvents.filter { $0.stepID == stepID }
            if let firstIncorrect = stepEvents.first(where: { $0.eventType == .verificationIncorrect }),
               let firstCorrectAfter = stepEvents.first(where: { $0.eventType == .verificationCorrect && $0.timestamp >= firstIncorrect.timestamp }) {
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
            avgProgressionLatencyMs: avgProgressionLatency
        )
    }
    
    /// Exports recorded research events as an anonymized RFC 4180 CSV string.
    public func exportCSV(for sessionID: UUID? = nil) -> String {
        let targetEvents = sessionID != nil ? events.filter { $0.sessionID == sessionID } : events
        var csv = ResearchEvent.csvHeader + "\n"
        for event in targetEvents {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    /// Clears all stored research event logs.
    public func clearLogs() {
        events.removeAll()
        sessionSequences.removeAll()
    }
}

// MARK: - Mock Research Logger

/// Thread-safe mock research logger for unit testing.
public final class MockResearchLogger: ResearchLogging, @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var loggedEvents: [ResearchEvent] = []
    
    public init() {}
    
    public func logEvent(_ event: ResearchEvent) async {
        lock.lock()
        defer { lock.unlock() }
        loggedEvents.append(event)
    }
    
    public func fetchEvents(for sessionID: UUID) async -> [ResearchEvent] {
        lock.lock()
        defer { lock.unlock() }
        return loggedEvents.filter { $0.sessionID == sessionID }
    }
    
    public func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics {
        lock.lock()
        defer { lock.unlock() }
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
    
    public func exportCSV(for sessionID: UUID?) async -> String {
        lock.lock()
        defer { lock.unlock() }
        let target = sessionID != nil ? loggedEvents.filter { $0.sessionID == sessionID } : loggedEvents
        var csv = ResearchEvent.csvHeader + "\n"
        for event in target {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    public func clearLogs() async {
        lock.lock()
        defer { lock.unlock() }
        loggedEvents.removeAll()
    }
}
