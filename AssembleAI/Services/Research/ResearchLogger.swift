//
//  ResearchLogger.swift
//  AssembleAI
//

import Foundation

/// Calculated research metrics for an evaluation session.
struct ResearchSessionMetrics: Sendable {
    let sessionID: UUID
    let durationSeconds: Int
    let completedStepsCount: Int
    let totalAttempts: Int
    let errorCount: Int
    let uncertainCount: Int
    let avgVerificationLatencyMs: Int
    let avgGuidanceLatencyMs: Int
}

/// Thread-safe local research logger capturing pseudonymous session metrics and CSV export functionality.
actor ResearchLogger {
    static let shared = ResearchLogger()
    
    private var events: [ResearchEvent] = []
    
    /// Records a research event locally.
    func logEvent(_ event: ResearchEvent) {
        events.append(event)
    }
    
    /// Returns all logged events for a given session.
    func fetchEvents(for sessionID: UUID) -> [ResearchEvent] {
        return events.filter { $0.sessionID == sessionID }
    }
    
    /// Calculates aggregate research metrics for a session.
    func calculateMetrics(for sessionID: UUID) -> ResearchSessionMetrics {
        let sessionEvents = fetchEvents(for: sessionID)
        
        let startEvent = sessionEvents.first { $0.eventType == .sessionStarted }
        let endEvent = sessionEvents.last { $0.eventType == .sessionCompleted || $0.eventType == .stepCompleted }
        
        let durationSec: Int
        if let start = startEvent, let end = endEvent {
            durationSec = Int(end.timestamp.timeIntervalSince(start.timestamp))
        } else {
            durationSec = 0
        }
        
        let stepCompletedEvents = sessionEvents.filter { $0.eventType == .stepCompleted }
        let verificationEvents = sessionEvents.filter { $0.eventType == .verificationCompleted }
        
        let totalAttempts = verificationEvents.count
        let errorCount = verificationEvents.filter { $0.verificationStatus == "incorrect" }.count
        let uncertainCount = verificationEvents.filter { $0.verificationStatus == "uncertain" }.count
        
        let verLatencies = verificationEvents.compactMap { $0.durationMilliseconds }
        let avgVerLatency = verLatencies.isEmpty ? 0 : verLatencies.reduce(0, +) / verLatencies.count
        
        let guidanceEvents = sessionEvents.filter { $0.eventType == .guidanceDisplayed }
        let guidLatencies = guidanceEvents.compactMap { $0.durationMilliseconds }
        let avgGuidLatency = guidLatencies.isEmpty ? 0 : guidLatencies.reduce(0, +) / guidLatencies.count
        
        return ResearchSessionMetrics(
            sessionID: sessionID,
            durationSeconds: max(0, durationSec),
            completedStepsCount: stepCompletedEvents.count,
            totalAttempts: totalAttempts,
            errorCount: errorCount,
            uncertainCount: uncertainCount,
            avgVerificationLatencyMs: avgVerLatency,
            avgGuidanceLatencyMs: avgGuidLatency
        )
    }
    
    /// Exports all recorded research events as an anonymized CSV string.
    func exportCSV() -> String {
        var csv = ResearchEvent.csvHeader + "\n"
        for event in events {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    /// Clears all stored research event logs.
    func clearLogs() {
        events.removeAll()
    }
}
