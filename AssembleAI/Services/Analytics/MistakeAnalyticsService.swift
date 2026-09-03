//
//  MistakeAnalyticsService.swift
//  AssembleAI
//

import Foundation

/// Structured telemetry event recorded during physical assembly.
nonisolated struct StepTelemetryRecord: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let sessionId: UUID
    let stepOrder: Int
    let stepTitle: String
    let durationSeconds: Double
    let attemptsCount: Int
    let encounteredMistakes: [String]
    let wasSuccessful: Bool
    let completedAt: Date
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        stepOrder: Int,
        stepTitle: String,
        durationSeconds: Double,
        attemptsCount: Int,
        encounteredMistakes: [String] = [],
        wasSuccessful: Bool,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.stepOrder = stepOrder
        self.stepTitle = stepTitle
        self.durationSeconds = durationSeconds
        self.attemptsCount = attemptsCount
        self.encounteredMistakes = encounteredMistakes
        self.wasSuccessful = wasSuccessful
        self.completedAt = completedAt
    }
}

/// Aggregated telemetry summary for an entire project guide.
nonisolated struct ProjectAnalyticsSummary: Sendable, Equatable {
    let totalSessions: Int
    let completionRate: Double
    let averageDurationSeconds: Double
    let highestFrictionStepOrder: Int?
    let topMistakes: [(mistake: String, count: Int)]
}

/// Service aggregating mistake frequencies, step durations, and user friction telemetry.
actor MistakeAnalyticsService {
    
    private var records: [StepTelemetryRecord] = []
    
    init(initialRecords: [StepTelemetryRecord] = []) {
        self.records = initialRecords
    }
    
    /// Records completion telemetry for a single assembly step.
    func recordStep(
        sessionId: UUID,
        stepOrder: Int,
        stepTitle: String,
        durationSeconds: Double,
        attemptsCount: Int,
        encounteredMistakes: [String],
        wasSuccessful: Bool
    ) {
        let record = StepTelemetryRecord(
            sessionId: sessionId,
            stepOrder: stepOrder,
            stepTitle: stepTitle,
            durationSeconds: durationSeconds,
            attemptsCount: attemptsCount,
            encounteredMistakes: encounteredMistakes,
            wasSuccessful: wasSuccessful
        )
        records.append(record)
    }
    
    /// Returns all recorded telemetry items.
    func getAllRecords() -> [StepTelemetryRecord] {
        records
    }
    
    /// Computes aggregated analytics summary across all recorded sessions.
    func computeAnalyticsSummary() -> ProjectAnalyticsSummary {
        guard !records.isEmpty else {
            return ProjectAnalyticsSummary(
                totalSessions: 0,
                completionRate: 0.0,
                averageDurationSeconds: 0.0,
                highestFrictionStepOrder: nil,
                topMistakes: []
            )
        }
        
        let uniqueSessions = Set(records.map(\.sessionId))
        let totalSessions = uniqueSessions.count
        
        // Average duration
        let totalDuration = records.map(\.durationSeconds).reduce(0.0, +)
        let avgDuration = totalDuration / Double(max(1, totalSessions))
        
        // Completion rate: fraction of steps that were successful
        let successfulSteps = records.filter(\.wasSuccessful).count
        let completionRate = Double(successfulSteps) / Double(records.count)
        
        // Find highest friction step (highest average attempts)
        var stepAttempts: [Int: (totalAttempts: Int, count: Int)] = [:]
        for r in records {
            let current = stepAttempts[r.stepOrder] ?? (0, 0)
            stepAttempts[r.stepOrder] = (current.totalAttempts + r.attemptsCount, current.count + 1)
        }
        
        let highestFriction = stepAttempts.max(by: { a, b in
            let avgA = Double(a.value.totalAttempts) / Double(max(1, a.value.count))
            let avgB = Double(b.value.totalAttempts) / Double(max(1, b.value.count))
            return avgA < avgB
        })?.key
        
        // Top mistakes count
        var mistakeCounts: [String: Int] = [:]
        for r in records {
            for m in r.encounteredMistakes {
                mistakeCounts[m, default: 0] += 1
            }
        }
        
        let sortedMistakes = mistakeCounts
            .sorted(by: { $0.value > $1.value })
            .prefix(5)
            .map { (mistake: $0.key, count: $0.value) }
        
        return ProjectAnalyticsSummary(
            totalSessions: totalSessions,
            completionRate: completionRate,
            averageDurationSeconds: avgDuration,
            highestFrictionStepOrder: highestFriction,
            topMistakes: sortedMistakes
        )
    }
    
    /// Clears recorded telemetry.
    func clear() {
        records.removeAll()
    }
}
