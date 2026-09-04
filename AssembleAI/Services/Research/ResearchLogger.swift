//
//  ResearchLogger.swift
//  AssembleAI
//
//  Comprehensive research data collection system for AssembleAI experimental evaluations.
//  Supports comparative evaluation of 4 visual-history strategies, empirical accuracy metrics,
//  real resident memory sampling, token consumption aggregation, latency profiling,
//  durable JSONL persistence, and RFC 4180 compliant CSV/JSON research exports.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Research Experiment Configuration

/// Experimental visual history strategy under evaluation.
///
/// Compares four distinct temporal context architectures:
/// - `currentFrame`: Strategy A — Baseline single current frame without temporal context.
/// - `lastNFrames`: Strategy B — Sliding window of the most recent N visual frames.
/// - `fullVisualHistory`: Strategy C — Unbounded chronological accumulation of all session frames.
/// - `compressedStateHistory`: Strategy D — Semantic state-aware keyframe representation with structural state summaries.
public enum VisualHistoryStrategy: String, Codable, Sendable, CaseIterable {
    case currentFrame = "currentFrame"
    case lastNFrames = "lastNFrames"
    case fullVisualHistory = "fullVisualHistory"
    case compressedStateHistory = "compressedStateHistory"
    
    public var displayName: String {
        switch self {
        case .currentFrame: return "Strategy A: Current Frame Only"
        case .lastNFrames: return "Strategy B: Last N Frames"
        case .fullVisualHistory: return "Strategy C: Full Visual History"
        case .compressedStateHistory: return "Strategy D: State-Aware Compressed History"
        }
    }
}

/// Persistent configuration and device metadata for a research evaluation session.
/// Guarantees reproducibility without storing personally identifying information (PII).
public struct ResearchSessionConfig: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let projectID: String
    public let interactionMode: InteractionMode
    public let strategy: VisualHistoryStrategy
    public let lastNFrames: Int?
    public let startedAt: Date
    public var endedAt: Date?
    public let schemaVersion: Int
    public let osVersion: String
    public let deviceModel: String
    public var memoryBeforeMB: Double?
    public var memoryAfterMB: Double?
    public var peakMemoryMB: Double?
    public var batteryCost: Double?
    public var batteryLevelStart: Float?
    public var batteryLevelEnd: Float?
    public var framesReceived: Int
    public var framesProcessed: Int
    public var framesIncludedInModelContext: Int
    public var framesDropped: Int
    
    public init(
        id: UUID = UUID(),
        projectID: String,
        interactionMode: InteractionMode = .liveTutor,
        strategy: VisualHistoryStrategy = .currentFrame,
        lastNFrames: Int? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        schemaVersion: Int = ResearchLogger.researchSchemaVersion,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        deviceModel: String = ResearchLogger.getDeviceModelIdentifier(),
        memoryBeforeMB: Double? = nil,
        memoryAfterMB: Double? = nil,
        peakMemoryMB: Double? = nil,
        batteryCost: Double? = nil,
        batteryLevelStart: Float? = nil,
        batteryLevelEnd: Float? = nil,
        framesReceived: Int = 0,
        framesProcessed: Int = 0,
        framesIncludedInModelContext: Int = 0,
        framesDropped: Int = 0
    ) {
        self.id = id
        self.projectID = projectID
        self.interactionMode = interactionMode
        self.strategy = strategy
        self.lastNFrames = strategy == .lastNFrames ? (lastNFrames ?? 5) : nil
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.schemaVersion = schemaVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.memoryBeforeMB = memoryBeforeMB
        self.memoryAfterMB = memoryAfterMB
        self.peakMemoryMB = peakMemoryMB
        self.batteryCost = batteryCost
        self.batteryLevelStart = batteryLevelStart
        self.batteryLevelEnd = batteryLevelEnd
        self.framesReceived = framesReceived
        self.framesProcessed = framesProcessed
        self.framesIncludedInModelContext = framesIncludedInModelContext
        self.framesDropped = framesDropped
    }
}

// MARK: - Memory Sampler Utility

/// Hardware-level resident memory sampling using Darwin Mach kernel task information.
/// Measures physical memory (resident size) actually occupied in RAM, rounded to megabytes.
public enum MemorySampler: Sendable {
    /// Returns current resident memory size in Megabytes (MB).
    /// Does not use private APIs or synthetic estimates.
    public static func currentResidentMemoryMB() -> Double {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0.0 }
        let bytes = Double(info.resident_size)
        return (bytes / (1024.0 * 1024.0) * 100.0).rounded() / 100.0
        #else
        return 0.0
        #endif
    }
}

// MARK: - Latency Statistics

/// Min, max, average, and total latency profile for a specific telemetry dimension.
public struct LatencyProfile: Codable, Sendable, Equatable {
    public let count: Int
    public let totalMs: Int
    public let avgMs: Int
    public let minMs: Int?
    public let maxMs: Int?
    
    public init(latencies: [Int]) {
        self.count = latencies.count
        if latencies.isEmpty {
            self.totalMs = 0
            self.avgMs = 0
            self.minMs = nil
            self.maxMs = nil
        } else {
            self.totalMs = latencies.reduce(0, +)
            self.avgMs = totalMs / count
            self.minMs = latencies.min()
            self.maxMs = latencies.max()
        }
    }
}

// MARK: - Research Session Metrics

/// Comprehensive statistical metrics calculated for an experimental evaluation session.
/// Keeps primary accuracy metrics and system efficiency metrics strictly decoupled.
public nonisolated struct ResearchSessionMetrics: Codable, Sendable, Equatable {
    // Session Identification & Configuration
    public let sessionID: UUID
    public let projectID: String
    public let mode: InteractionMode
    public let strategy: VisualHistoryStrategy
    public let lastNFrames: Int?
    public let schemaVersion: Int
    public let startedAt: Date?
    public let endedAt: Date?
    public let deviceModel: String
    public let iosVersion: String
    
    // Core Temporal & Progression Metrics
    public let taskCompletionTimeSeconds: Double
    public let completedStepsCount: Int
    public let totalVerificationAttempts: Int
    public let errorCount: Int
    public let uncertainCount: Int
    public let totalCorrectionTimeSeconds: Double
    public let interventionCount: Int
    public let userQuestionCount: Int
    
    // Primary Accuracy Metrics
    public let verificationAccuracy: Double?
    public let falseCompletionRate: Double?
    public let missedCompletionRate: Double?
    public let temporalConsistency: Double?
    
    // Token Consumption Metrics (Actual counts; nil when unavailable)
    public let totalInputTokens: Int?
    public let totalOutputTokens: Int?
    public let totalTokens: Int?
    
    // Latency Profiling (Milliseconds)
    public let avgInterventionLatencyMs: Int
    public let avgModelLatencyMs: Int
    public let avgSpeechLatencyMs: Int
    public let avgProgressionLatencyMs: Int
    public let avgVerificationLatencyMs: Int
    public let totalVerificationLatencyMs: Int
    public let minVerificationLatencyMs: Int?
    public let maxVerificationLatencyMs: Int?
    public let totalModelLatencyMs: Int
    public let minModelLatencyMs: Int?
    public let maxModelLatencyMs: Int?
    public let totalInterventionLatencyMs: Int
    public let totalProgressionLatencyMs: Int
    public let totalSpeechLatencyMs: Int
    
    // Memory Metrics (Megabytes)
    public let memoryBeforeMB: Double?
    public let memoryAfterMB: Double?
    public let peakMemoryMB: Double?
    
    // Energy / Battery Metrics
    public let batteryCost: Double?
    public let batteryLevelDelta: Float?
    
    // Visual Frame Processing Metrics
    public let framesReceived: Int
    public let framesProcessed: Int
    public let framesIncludedInModelContext: Int
    public let framesDropped: Int
    
    // Legacy Convenience Computed Properties
    public var durationSeconds: Int { Int(taskCompletionTimeSeconds) }
    public var totalAttempts: Int { totalVerificationAttempts }
    public var avgGuidanceLatencyMs: Int { avgModelLatencyMs }
    
    /// Aggregate latency average across all non-zero operational latencies.
    public var avgLatencyMs: Int {
        let values = [avgVerificationLatencyMs, avgModelLatencyMs, avgSpeechLatencyMs, avgProgressionLatencyMs, avgInterventionLatencyMs].filter { $0 > 0 }
        return values.isEmpty ? 0 : values.reduce(0, +) / values.count
    }
    
    /// Total operational latency accumulated during the session in milliseconds.
    public var totalLatencyMs: Int {
        totalVerificationLatencyMs + totalModelLatencyMs + totalSpeechLatencyMs + totalProgressionLatencyMs + totalInterventionLatencyMs
    }
    
    // MARK: - Initializer (Preserves 100% Backward Compatibility)
    public init(
        sessionID: UUID,
        projectID: String = "",
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
        avgVerificationLatencyMs: Int? = nil,
        // Extended Experimental Metrics
        strategy: VisualHistoryStrategy = .currentFrame,
        lastNFrames: Int? = nil,
        schemaVersion: Int = ResearchLogger.researchSchemaVersion,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        deviceModel: String = "",
        iosVersion: String = "",
        verificationAccuracy: Double? = nil,
        falseCompletionRate: Double? = nil,
        missedCompletionRate: Double? = nil,
        temporalConsistency: Double? = nil,
        totalInputTokens: Int? = nil,
        totalOutputTokens: Int? = nil,
        totalTokens: Int? = nil,
        totalVerificationLatencyMs: Int = 0,
        minVerificationLatencyMs: Int? = nil,
        maxVerificationLatencyMs: Int? = nil,
        totalModelLatencyMs: Int = 0,
        minModelLatencyMs: Int? = nil,
        maxModelLatencyMs: Int? = nil,
        totalInterventionLatencyMs: Int = 0,
        totalProgressionLatencyMs: Int = 0,
        totalSpeechLatencyMs: Int = 0,
        memoryBeforeMB: Double? = nil,
        memoryAfterMB: Double? = nil,
        peakMemoryMB: Double? = nil,
        batteryCost: Double? = nil,
        batteryLevelDelta: Float? = nil,
        framesReceived: Int = 0,
        framesProcessed: Int = 0,
        framesIncludedInModelContext: Int = 0,
        framesDropped: Int = 0
    ) {
        self.sessionID = sessionID
        self.projectID = projectID
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
        
        self.strategy = strategy
        self.lastNFrames = lastNFrames
        self.schemaVersion = schemaVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deviceModel = deviceModel.isEmpty ? ResearchLogger.getDeviceModelIdentifier() : deviceModel
        self.iosVersion = iosVersion.isEmpty ? ProcessInfo.processInfo.operatingSystemVersionString : iosVersion
        
        self.verificationAccuracy = verificationAccuracy
        self.falseCompletionRate = falseCompletionRate
        self.missedCompletionRate = missedCompletionRate
        self.temporalConsistency = temporalConsistency
        
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalTokens = totalTokens
        
        self.totalVerificationLatencyMs = totalVerificationLatencyMs
        self.minVerificationLatencyMs = minVerificationLatencyMs
        self.maxVerificationLatencyMs = maxVerificationLatencyMs
        self.totalModelLatencyMs = totalModelLatencyMs
        self.minModelLatencyMs = minModelLatencyMs
        self.maxModelLatencyMs = maxModelLatencyMs
        self.totalInterventionLatencyMs = totalInterventionLatencyMs
        self.totalProgressionLatencyMs = totalProgressionLatencyMs
        self.totalSpeechLatencyMs = totalSpeechLatencyMs
        
        self.memoryBeforeMB = memoryBeforeMB
        self.memoryAfterMB = memoryAfterMB
        self.peakMemoryMB = peakMemoryMB
        self.batteryCost = batteryCost
        self.batteryLevelDelta = batteryLevelDelta
        
        self.framesReceived = framesReceived
        self.framesProcessed = framesProcessed
        self.framesIncludedInModelContext = framesIncludedInModelContext
        self.framesDropped = framesDropped
    }
    
    // MARK: - Summary CSV Serialization (RFC 4180 Compliant)
    
    /// RFC 4180 header for session-level statistical summary export.
    public static var summaryCSVHeader: String {
        [
            "schema_version",
            "session_id",
            "project_id",
            "interaction_mode",
            "strategy",
            "last_n",
            "started_at",
            "ended_at",
            "device_model",
            "ios_version",
            "task_completion_time_sec",
            "completed_steps",
            "verification_attempts",
            "error_count",
            "uncertain_count",
            "correction_time_sec",
            "intervention_count",
            "user_question_count",
            "verification_accuracy",
            "false_completion_rate",
            "missed_completion_rate",
            "temporal_consistency",
            "total_tokens",
            "input_tokens",
            "output_tokens",
            "avg_latency_ms",
            "total_latency_ms",
            "avg_verification_latency_ms",
            "avg_model_latency_ms",
            "avg_speech_latency_ms",
            "avg_progression_latency_ms",
            "avg_intervention_latency_ms",
            "memory_before_mb",
            "memory_after_mb",
            "peak_memory_mb",
            "energy_cost",
            "frames_received",
            "frames_processed",
            "frames_in_context",
            "frames_dropped"
        ].joined(separator: ",")
    }
    
    /// RFC 4180 row formatting for statistical analysis in Excel, Python/pandas, R, and SPSS.
    public var summaryCSVLine: String {
        let isoFormatter = ISO8601DateFormatter()
        let startStr = startedAt.map { isoFormatter.string(from: $0) } ?? ""
        let endStr = endedAt.map { isoFormatter.string(from: $0) } ?? ""
        
        let cols: [String] = [
            "\(schemaVersion)",
            sessionID.uuidString,
            ResearchLogger.escapeCSV(projectID),
            mode.rawValue,
            strategy.rawValue,
            lastNFrames.map { "\($0)" } ?? "",
            startStr,
            endStr,
            ResearchLogger.escapeCSV(deviceModel),
            ResearchLogger.escapeCSV(iosVersion),
            String(format: "%.2f", taskCompletionTimeSeconds),
            "\(completedStepsCount)",
            "\(totalVerificationAttempts)",
            "\(errorCount)",
            "\(uncertainCount)",
            String(format: "%.2f", totalCorrectionTimeSeconds),
            "\(interventionCount)",
            "\(userQuestionCount)",
            verificationAccuracy.map { String(format: "%.4f", $0) } ?? "",
            falseCompletionRate.map { String(format: "%.4f", $0) } ?? "",
            missedCompletionRate.map { String(format: "%.4f", $0) } ?? "",
            temporalConsistency.map { String(format: "%.4f", $0) } ?? "",
            totalTokens.map { "\($0)" } ?? "",
            totalInputTokens.map { "\($0)" } ?? "",
            totalOutputTokens.map { "\($0)" } ?? "",
            "\(avgLatencyMs)",
            "\(totalLatencyMs)",
            "\(avgVerificationLatencyMs)",
            "\(avgModelLatencyMs)",
            "\(avgSpeechLatencyMs)",
            "\(avgProgressionLatencyMs)",
            "\(avgInterventionLatencyMs)",
            memoryBeforeMB.map { String(format: "%.2f", $0) } ?? "",
            memoryAfterMB.map { String(format: "%.2f", $0) } ?? "",
            peakMemoryMB.map { String(format: "%.2f", $0) } ?? "",
            batteryCost.map { String(format: "%.4f", $0) } ?? "",
            "\(framesReceived)",
            "\(framesProcessed)",
            "\(framesIncludedInModelContext)",
            "\(framesDropped)"
        ]
        
        return cols.joined(separator: ",")
    }
}

// MARK: - Research Logging Protocol

/// Abstract interface for recording research telemetry events and managing evaluation sessions.
public protocol ResearchLogging: Sendable {
    // Preserved Existing API
    func logEvent(_ event: ResearchEvent) async
    func fetchEvents(for sessionID: UUID) async -> [ResearchEvent]
    func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics
    func exportCSV(for sessionID: UUID?) async -> String
    func clearLogs() async
    
    // Research Session Lifecycle & Persistence Extensions
    func startResearchSession(
        projectID: String,
        strategy: VisualHistoryStrategy,
        lastNFrames: Int?,
        mode: InteractionMode
    ) async -> UUID
    
    func endResearchSession(
        sessionID: UUID,
        externalBatteryCost: Double?
    ) async -> ResearchSessionMetrics
    
    func getSessionConfig(for sessionID: UUID) async -> ResearchSessionConfig?
    func fetchAllSessions() async -> [ResearchSessionConfig]
    func getTelemetryStats() async -> (sessionCount: Int, eventCount: Int)
    
    // Disk Export Methods
    func exportCSVFile(for sessionID: UUID?) async throws -> URL
    func exportJSON(for sessionID: UUID?) async throws -> String
    func exportJSONFile(for sessionID: UUID?) async throws -> URL
    func exportSummaryCSV() async -> String
    func exportSummaryCSVFile() async throws -> URL
}

// Default parameter extensions for convenience
public extension ResearchLogging {
    func startResearchSession(
        projectID: String,
        strategy: VisualHistoryStrategy,
        lastNFrames: Int? = nil
    ) async -> UUID {
        await startResearchSession(projectID: projectID, strategy: strategy, lastNFrames: lastNFrames, mode: .liveTutor)
    }
    
    func endResearchSession(sessionID: UUID) async -> ResearchSessionMetrics {
        await endResearchSession(sessionID: sessionID, externalBatteryCost: nil)
    }
}

// MARK: - Concrete Research Logger Actor

/// Thread-safe local research logger capturing pseudonymous session metrics, monotonic sequencing,
/// durable JSONL persistence in `Application Support/ResearchData/`, and RFC 4180 export to `Documents/ResearchExports/`.
public actor ResearchLogger: ResearchLogging {
    public static let shared = ResearchLogger()
    
    /// Current research data schema version. Incremented when telemetry model evolves.
    public static let researchSchemaVersion: Int = 1
    
    // In-Memory State
    private var events: [ResearchEvent] = []
    private var sessionSequences: [UUID: Int] = [:]
    private var sessions: [UUID: ResearchSessionConfig] = [:]
    
    // Persistence File Paths
    private let storageDirectoryURL: URL
    private let eventsFileURL: URL
    private let sessionsFileURL: URL
    
    /// Initializes ResearchLogger with persistent local disk storage.
    /// - Parameter customBaseDirectory: Optional custom directory for testing or isolated environments.
    public init(customBaseDirectory: URL? = nil) {
        let baseDir: URL
        if let custom = customBaseDirectory {
            baseDir = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            baseDir = appSupport.appendingPathComponent("ResearchData", isDirectory: true)
        }
        self.storageDirectoryURL = baseDir
        self.eventsFileURL = baseDir.appendingPathComponent("events.jsonl")
        self.sessionsFileURL = baseDir.appendingPathComponent("sessions.json")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        
        // Load persisted records
        self.loadPersistedRecords()
    }
    
    // MARK: - Session Lifecycle
    
    /// Starts a new experimental research session with the specified visual history strategy.
    /// Records initial memory snapshot and emits a `.sessionStarted` event.
    public func startResearchSession(
        projectID: String,
        strategy: VisualHistoryStrategy,
        lastNFrames: Int? = nil,
        mode: InteractionMode = .liveTutor
    ) -> UUID {
        let sessionID = UUID()
        let mem = MemorySampler.currentResidentMemoryMB()
        
        #if canImport(UIKit)
        let battery = UIDevice.current.isBatteryMonitoringEnabled ? UIDevice.current.batteryLevel : nil
        #else
        let battery: Float? = nil
        #endif
        
        let config = ResearchSessionConfig(
            id: sessionID,
            projectID: projectID,
            interactionMode: mode,
            strategy: strategy,
            lastNFrames: strategy == .lastNFrames ? (lastNFrames ?? 5) : nil,
            startedAt: Date(),
            endedAt: nil,
            schemaVersion: Self.researchSchemaVersion,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: Self.getDeviceModelIdentifier(),
            memoryBeforeMB: mem > 0 ? mem : nil,
            memoryAfterMB: nil,
            peakMemoryMB: mem > 0 ? mem : nil,
            batteryCost: nil,
            batteryLevelStart: battery,
            batteryLevelEnd: nil,
            framesReceived: 0,
            framesProcessed: 0,
            framesIncludedInModelContext: 0,
            framesDropped: 0
        )
        
        sessions[sessionID] = config
        persistSessions()
        
        let projectUUID = UUID(uuidString: projectID) ?? UUID()
        let startEvent = ResearchEvent(
            sessionID: sessionID,
            projectID: projectUUID,
            mode: mode,
            eventType: .sessionStarted,
            metadata: [
                "strategy": strategy.rawValue,
                "lastNFrames": config.lastNFrames.map { "\($0)" } ?? "none",
                "schemaVersion": "\(Self.researchSchemaVersion)",
                "memoryBeforeMB": String(format: "%.2f", mem)
            ]
        )
        logEvent(startEvent)
        
        return sessionID
    }
    
    /// Completes an active research run, records final memory and optional battery cost,
    /// persists final state, and computes comprehensive session metrics.
    public func endResearchSession(
        sessionID: UUID,
        externalBatteryCost: Double? = nil
    ) -> ResearchSessionMetrics {
        let mem = MemorySampler.currentResidentMemoryMB()
        
        #if canImport(UIKit)
        let battery = UIDevice.current.isBatteryMonitoringEnabled ? UIDevice.current.batteryLevel : nil
        #else
        let battery: Float? = nil
        #endif
        
        if var config = sessions[sessionID] {
            config.endedAt = Date()
            config.memoryAfterMB = mem > 0 ? mem : nil
            if let currentPeak = config.peakMemoryMB {
                config.peakMemoryMB = max(currentPeak, mem)
            } else if mem > 0 {
                config.peakMemoryMB = mem
            }
            if let cost = externalBatteryCost {
                config.batteryCost = cost
            }
            config.batteryLevelEnd = battery
            sessions[sessionID] = config
            persistSessions()
        }
        
        let projectUUID = UUID(uuidString: sessions[sessionID]?.projectID ?? "") ?? UUID()
        let mode = sessions[sessionID]?.interactionMode ?? .liveTutor
        let endEvent = ResearchEvent(
            sessionID: sessionID,
            projectID: projectUUID,
            mode: mode,
            eventType: .sessionCompleted,
            metadata: [
                "memoryAfterMB": String(format: "%.2f", mem),
                "batteryCost": externalBatteryCost.map { "\($0)" } ?? "none"
            ]
        )
        logEvent(endEvent)
        
        return calculateMetrics(for: sessionID)
    }
    
    /// Returns the active or saved session configuration.
    public func getSessionConfig(for sessionID: UUID) -> ResearchSessionConfig? {
        sessions[sessionID]
    }
    
    /// Returns all registered research session configurations.
    public func fetchAllSessions() -> [ResearchSessionConfig] {
        Array(sessions.values).sorted { $0.startedAt < $1.startedAt }
    }
    
    /// Returns live telemetry statistics (total unique sessions count and total event count).
    public func getTelemetryStats() -> (sessionCount: Int, eventCount: Int) {
        let knownIDs = Set(sessions.keys)
        let eventIDs = Set(events.map(\.sessionID))
        let sessionCount = knownIDs.union(eventIDs).count
        return (sessionCount, events.count)
    }
    
    // MARK: - Frame & Resource Tracking Helpers
    
    /// Updates frame counters for an active evaluation session.
    public func recordFrameProcessing(
        sessionID: UUID,
        received: Int = 0,
        processed: Int = 0,
        includedInContext: Int = 0,
        dropped: Int = 0
    ) {
        if var config = sessions[sessionID] {
            config.framesReceived += received
            config.framesProcessed += processed
            config.framesIncludedInModelContext += includedInContext
            config.framesDropped += dropped
            sessions[sessionID] = config
            persistSessions()
        }
    }
    
    /// Samples resident memory and updates peak memory if higher than previous reading.
    public func samplePeakMemory(for sessionID: UUID) {
        let mem = MemorySampler.currentResidentMemoryMB()
        guard mem > 0 else { return }
        if var config = sessions[sessionID] {
            config.peakMemoryMB = max(config.peakMemoryMB ?? 0, mem)
            sessions[sessionID] = config
            persistSessions()
        }
    }
    
    // MARK: - Event Logging (Preserved API)
    
    /// Records a research telemetry event with automatic monotonic sequence numbering.
    /// Appends immediately to in-memory list and writes append-only JSONL to disk.
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
        appendEventToDisk(sequencedEvent)
        
        // Auto-register session configuration if not created via startResearchSession
        if sessions[event.sessionID] == nil {
            let stratStr = event.metadata["strategy"] ?? ""
            let strategy = VisualHistoryStrategy(rawValue: stratStr) ?? .currentFrame
            let mem = MemorySampler.currentResidentMemoryMB()
            let config = ResearchSessionConfig(
                id: event.sessionID,
                projectID: event.projectID.uuidString,
                interactionMode: event.mode,
                strategy: strategy,
                lastNFrames: strategy == .lastNFrames ? (Int(event.metadata["lastNFrames"] ?? "5") ?? 5) : nil,
                startedAt: event.timestamp,
                endedAt: nil,
                schemaVersion: Self.researchSchemaVersion,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: Self.getDeviceModelIdentifier(),
                memoryBeforeMB: mem > 0 ? mem : nil,
                memoryAfterMB: nil,
                peakMemoryMB: mem > 0 ? mem : nil,
                batteryCost: nil,
                batteryLevelStart: nil,
                batteryLevelEnd: nil,
                framesReceived: 0,
                framesProcessed: 0,
                framesIncludedInModelContext: 0,
                framesDropped: 0
            )
            sessions[event.sessionID] = config
            persistSessions()
        }
        
        if event.eventType == .sessionCompleted, var config = sessions[event.sessionID] {
            config.endedAt = event.timestamp
            let mem = MemorySampler.currentResidentMemoryMB()
            if mem > 0 {
                config.memoryAfterMB = mem
                config.peakMemoryMB = max(config.peakMemoryMB ?? 0, mem)
            }
            sessions[event.sessionID] = config
            persistSessions()
        }
        
        // Synchronize frame counts if present in event metadata
        if let recStr = event.metadata["frames_received"], let rec = Int(recStr) {
            recordFrameProcessing(sessionID: event.sessionID, received: rec)
        }
        if let procStr = event.metadata["frames_processed"], let proc = Int(procStr) {
            recordFrameProcessing(sessionID: event.sessionID, processed: proc)
        }
        if let ctxStr = event.metadata["frames_in_context"], let ctx = Int(ctxStr) {
            recordFrameProcessing(sessionID: event.sessionID, includedInContext: ctx)
        }
        if let dropStr = event.metadata["frames_dropped"], let drop = Int(dropStr) {
            recordFrameProcessing(sessionID: event.sessionID, dropped: drop)
        }
    }
    
    /// Returns all logged events for a given session sorted chronologically by sequence.
    public func fetchEvents(for sessionID: UUID) -> [ResearchEvent] {
        return events.filter { $0.sessionID == sessionID }.sorted { $0.sequence < $1.sequence }
    }
    
    // MARK: - Metrics Calculation
    
    /// Calculates aggregate empirical research metrics for an experimental session.
    ///
    /// Primary Accuracy Metrics Defined:
    /// - `Verification Accuracy`: correct verifications / total verification attempts.
    /// - `False Completion Rate`: false positive verifications / applicable verification decisions.
    /// - `Missed Completion Rate`: missed true completions / actual completed steps.
    /// - `Temporal Consistency`: ratio of consistent consecutive verification observations across steps.
    ///
    /// Efficiency Metrics Defined:
    /// - Actual token counts (input, output, total) parsed directly from telemetry events.
    /// - Latency profile (average, total, min, max) for verification, model, speech, and progression.
    /// - Physical resident memory (MB) before, after, and peak.
    /// - Energy / battery cost (external instrumented or nil).
    /// - Visual frame throughput (received, processed, in-context, dropped).
    public func calculateMetrics(for sessionID: UUID) -> ResearchSessionMetrics {
        let sessionEvents = fetchEvents(for: sessionID)
        let config = sessions[sessionID]
        
        let projectIDStr = config?.projectID ?? sessionEvents.first?.projectID.uuidString ?? ""
        let mode = config?.interactionMode ?? sessionEvents.first?.mode ?? .liveTutor
        let strategy = config?.strategy ?? .currentFrame
        let lastNFrames = config?.lastNFrames
        let schema = config?.schemaVersion ?? Self.researchSchemaVersion
        let deviceModel = config?.deviceModel ?? Self.getDeviceModelIdentifier()
        let osVersion = config?.osVersion ?? ProcessInfo.processInfo.operatingSystemVersionString
        
        let startedAt = config?.startedAt ?? sessionEvents.first { $0.eventType == .sessionStarted }?.timestamp ?? sessionEvents.first?.timestamp
        let endedAt = config?.endedAt ?? sessionEvents.last { $0.eventType == .sessionCompleted }?.timestamp ?? sessionEvents.last?.timestamp
        
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
        let verProfile = LatencyProfile(latencies: verLatencies)
        
        // 4. Correction Time Calculation (Time from first incorrect to first subsequent correct per step)
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
        
        // 6. Latencies (Model, Speech, Progression, Intervention)
        let modelLatencies = sessionEvents.filter { $0.eventType == .assistantResponseGenerated }.compactMap(\.durationMilliseconds)
        let modelProfile = LatencyProfile(latencies: modelLatencies)
        
        let speechLatencies = sessionEvents.filter { $0.eventType == .assistantSpeechStarted }.compactMap(\.durationMilliseconds)
        let speechProfile = LatencyProfile(latencies: speechLatencies)
        
        let interventionLatencies = interventionEvents.compactMap(\.durationMilliseconds)
        let interventionProfile = LatencyProfile(latencies: interventionLatencies)
        
        let progressionLatencies = sessionEvents.filter { $0.eventType == .stepCompleted }.compactMap(\.durationMilliseconds)
        let progressionProfile = LatencyProfile(latencies: progressionLatencies)
        
        // 7. Primary Accuracy Metric: Verification Accuracy
        // Formula: correct verifications / total verification attempts
        let verificationAccuracy: Double?
        if totalVerifications > 0 {
            verificationAccuracy = Double(correctEvents.count) / Double(totalVerifications)
        } else {
            verificationAccuracy = nil
        }
        
        // 8. Primary Accuracy Metric: False Completion Rate
        // Formula: false positive verifications / applicable verification decisions
        // A verification is counted as false completion if marked with groundTruth=incomplete or if
        // a verificationCorrect was immediately followed by verificationIncorrect/intervention on the same step.
        var falsePositiveCount = 0
        for stepID in stepIDs {
            let stepVerEvents = sessionEvents.filter { $0.stepID == stepID && ($0.eventType == .verificationCorrect || $0.eventType == .verificationIncorrect || $0.eventType == .verificationUncertain || $0.eventType == .interventionTriggered) }
            for i in 0..<stepVerEvents.count {
                let ev = stepVerEvents[i]
                if ev.eventType == .verificationCorrect || (ev.eventType == .verificationCompleted && ev.verificationStatus == "correct") {
                    if ev.metadata["isFalsePositive"] == "true" || ev.metadata["groundTruth"] == "incomplete" || ev.metadata["groundTruth"] == "incorrect" {
                        falsePositiveCount += 1
                    } else if i + 1 < stepVerEvents.count {
                        let nextEv = stepVerEvents[i + 1]
                        if nextEv.eventType == .verificationIncorrect || nextEv.eventType == .interventionTriggered {
                            falsePositiveCount += 1
                        }
                    }
                }
            }
        }
        let falseCompletionRate: Double?
        if totalVerifications > 0 {
            falseCompletionRate = Double(falsePositiveCount) / Double(totalVerifications)
        } else {
            falseCompletionRate = nil
        }
        
        // 9. Primary Accuracy Metric: Missed Completion Rate
        // Formula: missed true completions / actual completed steps
        // A step has a missed completion if it completed but required manual intervention or was preceded by false rejection.
        var missedCompletionCount = 0
        for stepID in stepIDs {
            let stepEvs = sessionEvents.filter { $0.stepID == stepID }
            let hasCompleted = stepEvs.contains { $0.eventType == .stepCompleted }
            let explicitMiss = stepEvs.contains { $0.metadata["isMissedCompletion"] == "true" || ($0.metadata["groundTruth"] == "completed" && ($0.eventType == .verificationIncorrect || $0.eventType == .verificationUncertain)) }
            let hadNoCorrectPriorToCompletion = hasCompleted && !stepEvs.contains { $0.eventType == .verificationCorrect || ($0.eventType == .verificationCompleted && $0.verificationStatus == "correct") }
            if explicitMiss || hadNoCorrectPriorToCompletion {
                missedCompletionCount += 1
            }
        }
        let missedCompletionRate: Double?
        if completedSteps > 0 {
            missedCompletionRate = Double(missedCompletionCount) / Double(completedSteps)
        } else {
            missedCompletionRate = nil
        }
        
        // 10. Primary Accuracy Metric: Temporal Consistency
        // Formula: Consistent transitions / total consecutive observations across steps.
        // Consecutive observations of the same step are consistent if the classification status is stable or monotonic (incorrect -> correct).
        var totalTransitions = 0
        var consistentTransitions = 0
        for stepID in stepIDs {
            let stepVerEvents = sessionEvents.filter {
                $0.stepID == stepID && ($0.eventType == .verificationCorrect || $0.eventType == .verificationIncorrect || $0.eventType == .verificationUncertain)
            }.sorted { $0.sequence < $1.sequence }
            
            guard stepVerEvents.count >= 2 else { continue }
            for i in 0..<(stepVerEvents.count - 1) {
                totalTransitions += 1
                let current = stepVerEvents[i].eventType
                let next = stepVerEvents[i + 1].eventType
                if current == next {
                    // Stable decision
                    consistentTransitions += 1
                } else if (current == .verificationIncorrect || current == .verificationUncertain) && next == .verificationCorrect {
                    // Valid monotonic task progression
                    consistentTransitions += 1
                }
                // Regression from correct to incorrect/uncertain counts as temporal inconsistency (jitter)
            }
        }
        let temporalConsistency: Double?
        if totalTransitions > 0 {
            temporalConsistency = Double(consistentTransitions) / Double(totalTransitions)
        } else {
            temporalConsistency = nil
        }
        
        // 11. Token Consumption (Sum actual tokens from metadata; never fabricate)
        var totalInTokens = 0
        var totalOutTokens = 0
        var foundTokenData = false
        for event in sessionEvents {
            if let inTokStr = event.metadata["input_tokens"] ?? event.metadata["inputTokens"], let inTok = Int(inTokStr) {
                totalInTokens += inTok
                foundTokenData = true
            }
            if let outTokStr = event.metadata["output_tokens"] ?? event.metadata["outputTokens"], let outTok = Int(outTokStr) {
                totalOutTokens += outTok
                foundTokenData = true
            }
        }
        let totalTokensVal: Int? = foundTokenData ? (totalInTokens + totalOutTokens) : nil
        let totalInputTokensVal: Int? = foundTokenData ? totalInTokens : nil
        let totalOutputTokensVal: Int? = foundTokenData ? totalOutTokens : nil
        
        // 12. Memory Consumption
        let memBefore = config?.memoryBeforeMB
        let memAfter = config?.memoryAfterMB
        var peakMem = config?.peakMemoryMB
        for ev in sessionEvents {
            if let mStr = ev.metadata["memory_mb"] ?? ev.metadata["resident_memory_mb"], let mVal = Double(mStr) {
                peakMem = max(peakMem ?? 0.0, mVal)
            }
        }
        
        // 13. Energy / Battery
        let batteryCost = config?.batteryCost
        let batteryDelta: Float?
        if let bStart = config?.batteryLevelStart, let bEnd = config?.batteryLevelEnd, bStart >= 0, bEnd >= 0 {
            batteryDelta = (bStart - bEnd) * 100.0
        } else {
            batteryDelta = nil
        }
        
        // 14. Visual Frames
        let framesRec = config?.framesReceived ?? 0
        let framesProc = config?.framesProcessed ?? 0
        let framesCtx = config?.framesIncludedInModelContext ?? 0
        let framesDrop = config?.framesDropped ?? 0
        
        return ResearchSessionMetrics(
            sessionID: sessionID,
            projectID: projectIDStr,
            mode: mode,
            taskCompletionTimeSeconds: totalTime,
            completedStepsCount: completedSteps,
            totalVerificationAttempts: totalVerifications,
            errorCount: incorrectEvents.count,
            uncertainCount: uncertainEvents.count,
            totalCorrectionTimeSeconds: totalCorrectionTime,
            interventionCount: interventionEvents.count,
            userQuestionCount: userVoiceEvents.count,
            avgInterventionLatencyMs: interventionProfile.avgMs,
            avgModelLatencyMs: modelProfile.avgMs,
            avgSpeechLatencyMs: speechProfile.avgMs,
            avgProgressionLatencyMs: progressionProfile.avgMs,
            avgVerificationLatencyMs: verProfile.avgMs,
            strategy: strategy,
            lastNFrames: lastNFrames,
            schemaVersion: schema,
            startedAt: startedAt,
            endedAt: endedAt,
            deviceModel: deviceModel,
            iosVersion: osVersion,
            verificationAccuracy: verificationAccuracy,
            falseCompletionRate: falseCompletionRate,
            missedCompletionRate: missedCompletionRate,
            temporalConsistency: temporalConsistency,
            totalInputTokens: totalInputTokensVal,
            totalOutputTokens: totalOutputTokensVal,
            totalTokens: totalTokensVal,
            totalVerificationLatencyMs: verProfile.totalMs,
            minVerificationLatencyMs: verProfile.minMs,
            maxVerificationLatencyMs: verProfile.maxMs,
            totalModelLatencyMs: modelProfile.totalMs,
            minModelLatencyMs: modelProfile.minMs,
            maxModelLatencyMs: modelProfile.maxMs,
            totalInterventionLatencyMs: interventionProfile.totalMs,
            totalProgressionLatencyMs: progressionProfile.totalMs,
            totalSpeechLatencyMs: speechProfile.totalMs,
            memoryBeforeMB: memBefore,
            memoryAfterMB: memAfter,
            peakMemoryMB: peakMem,
            batteryCost: batteryCost,
            batteryLevelDelta: batteryDelta,
            framesReceived: framesRec,
            framesProcessed: framesProc,
            framesIncludedInModelContext: framesCtx,
            framesDropped: framesDrop
        )
    }
    
    // MARK: - Export Methods (Preserved & Extended)
    
    /// Exports recorded research events as an anonymized RFC 4180 CSV string (Event-Level).
    /// Preserves exact backward-compatible header and line formatting for unit tests.
    public func exportCSV(for sessionID: UUID? = nil) -> String {
        let targetEvents = sessionID != nil ? events.filter { $0.sessionID == sessionID } : events
        var csv = ResearchEvent.csvHeader + "\n"
        for event in targetEvents {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    /// Writes event-level CSV file into `Documents/ResearchExports/` and returns its file URL.
    public func exportCSVFile(for sessionID: UUID? = nil) throws -> URL {
        let content = exportCSV(for: sessionID)
        let dir = try getExportsDirectoryURL()
        let filename: String
        if let sid = sessionID {
            filename = "AssembleAI_Research_Session_\(sid.uuidString).csv"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: Date())
            filename = "AssembleAI_Research_AllSessions_\(dateStr).csv"
        }
        let fileURL = dir.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Exports recorded research events as pretty-printed JSON.
    public func exportJSON(for sessionID: UUID? = nil) throws -> String {
        let targetEvents = sessionID != nil ? events.filter { $0.sessionID == sessionID } : events
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(targetEvents)
        guard let jsonStr = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return jsonStr
    }
    
    /// Writes event-level JSON file into `Documents/ResearchExports/` and returns its file URL.
    public func exportJSONFile(for sessionID: UUID? = nil) throws -> URL {
        let content = try exportJSON(for: sessionID)
        let dir = try getExportsDirectoryURL()
        let filename: String
        if let sid = sessionID {
            filename = "AssembleAI_Research_Session_\(sid.uuidString).json"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: Date())
            filename = "AssembleAI_Research_AllSessions_\(dateStr).json"
        }
        let fileURL = dir.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Exports a research-summary CSV containing ONE ROW PER SESSION.
    /// Ideal for statistical analysis in Python/pandas, R, SPSS, or Microsoft Excel.
    public func exportSummaryCSV() -> String {
        let knownIDs = Set(sessions.keys)
        let eventIDs = Set(events.map(\.sessionID))
        let allIDs = Array(knownIDs.union(eventIDs)).sorted { id1, id2 in
            let d1 = sessions[id1]?.startedAt ?? events.first { $0.sessionID == id1 }?.timestamp ?? Date.distantPast
            let d2 = sessions[id2]?.startedAt ?? events.first { $0.sessionID == id2 }?.timestamp ?? Date.distantPast
            return d1 < d2
        }
        
        var lines: [String] = [ResearchSessionMetrics.summaryCSVHeader]
        for id in allIDs {
            let metrics = calculateMetrics(for: id)
            lines.append(metrics.summaryCSVLine)
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
    
    /// Writes session-level summary CSV file into `Documents/ResearchExports/` and returns its file URL.
    public func exportSummaryCSVFile() throws -> URL {
        let content = exportSummaryCSV()
        let dir = try getExportsDirectoryURL()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        let filename = "AssembleAI_Research_Summary_\(dateStr).csv"
        let fileURL = dir.appendingPathComponent(filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - State Management & Disk Cleaning
    
    /// Clears all stored research logs from memory and deletes persisted records on disk.
    public func clearLogs() {
        events.removeAll()
        sessionSequences.removeAll()
        sessions.removeAll()
        
        if FileManager.default.fileExists(atPath: eventsFileURL.path) {
            try? FileManager.default.removeItem(at: eventsFileURL)
        }
        if FileManager.default.fileExists(atPath: sessionsFileURL.path) {
            try? FileManager.default.removeItem(at: sessionsFileURL)
        }
    }
    
    // MARK: - Internal Persistence Helpers
    
    private func loadPersistedRecords() {
        // 1. Load Sessions
        if FileManager.default.fileExists(atPath: sessionsFileURL.path),
           let data = try? Data(contentsOf: sessionsFileURL) {
            let decoder = JSONDecoder()
            if let loaded = try? decoder.decode([ResearchSessionConfig].self, from: data) {
                for s in loaded {
                    self.sessions[s.id] = s
                }
            }
        }
        
        // 2. Load Events from JSONL (graceful line-by-line decoding)
        if FileManager.default.fileExists(atPath: eventsFileURL.path),
           let data = try? Data(contentsOf: eventsFileURL),
           let content = String(data: data, encoding: .utf8) {
            let decoder = JSONDecoder()
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if let lineData = trimmed.data(using: .utf8),
                   let event = try? decoder.decode(ResearchEvent.self, from: lineData) {
                    self.events.append(event)
                    self.sessionSequences[event.sessionID] = max(self.sessionSequences[event.sessionID] ?? 0, event.sequence)
                }
            }
        }
    }
    
    private func appendEventToDisk(_ event: ResearchEvent) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(event),
              var lineStr = String(data: data, encoding: .utf8) else { return }
        lineStr += "\n"
        guard let lineData = lineStr.data(using: .utf8) else { return }
        
        if FileManager.default.fileExists(atPath: eventsFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: eventsFileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(lineData)
            }
        } else {
            try? lineData.write(to: eventsFileURL, options: .atomic)
        }
    }
    
    private func persistSessions() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let list = Array(sessions.values)
        if let data = try? encoder.encode(list) {
            try? data.write(to: sessionsFileURL, options: .atomic)
        }
    }
    
    private func getExportsDirectoryURL() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let exports = docs.appendingPathComponent("ResearchExports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: exports.path) {
            try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        }
        return exports
    }
    
    // MARK: - Utility Functions
    
    /// Safely escapes CSV fields per RFC 4180 rules.
    public static func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }
    
    /// Obtains hardware device identifier without personal identifiers (e.g., "iPhone15,2").
    public static func getDeviceModelIdentifier() -> String {
        #if canImport(Darwin)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { idStr, element in
            guard let val = element.value as? Int8, val != 0 else { return idStr }
            return idStr + String(UnicodeScalar(UInt8(val)))
        }
        return identifier.isEmpty ? "iPhone" : identifier
        #else
        return "Apple Device"
        #endif
    }
}

// MARK: - Mock Research Logger

/// Actor-isolated mock research logger for unit and integration testing.
public actor MockResearchLogger: ResearchLogging {
    public private(set) var loggedEvents: [ResearchEvent] = []
    private var mockSessions: [UUID: ResearchSessionConfig] = [:]
    
    public init() {}
    
    public func logEvent(_ event: ResearchEvent) async {
        loggedEvents.append(event)
    }
    
    public func fetchEvents(for sessionID: UUID) async -> [ResearchEvent] {
        return loggedEvents.filter { $0.sessionID == sessionID }
    }
    
    public func calculateMetrics(for sessionID: UUID) async -> ResearchSessionMetrics {
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
    
    public func exportCSV(for sessionID: UUID? = nil) async -> String {
        let target = sessionID != nil ? loggedEvents.filter { $0.sessionID == sessionID } : loggedEvents
        var csv = ResearchEvent.csvHeader + "\n"
        for event in target {
            csv += event.csvLine + "\n"
        }
        return csv
    }
    
    public func clearLogs() async {
        loggedEvents.removeAll()
        mockSessions.removeAll()
    }
    
    public func startResearchSession(
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
    
    public func endResearchSession(
        sessionID: UUID,
        externalBatteryCost: Double?
    ) async -> ResearchSessionMetrics {
        return await calculateMetrics(for: sessionID)
    }
    
    public func getSessionConfig(for sessionID: UUID) async -> ResearchSessionConfig? {
        return mockSessions[sessionID]
    }
    
    public func fetchAllSessions() async -> [ResearchSessionConfig] {
        return Array(mockSessions.values)
    }
    
    public func getTelemetryStats() async -> (sessionCount: Int, eventCount: Int) {
        let knownIDs = Set(mockSessions.keys)
        let eventIDs = Set(loggedEvents.map(\.sessionID))
        return (knownIDs.union(eventIDs).count, loggedEvents.count)
    }
    
    public func exportCSVFile(for sessionID: UUID?) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_export.csv")
        try await exportCSV(for: sessionID).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    public func exportJSON(for sessionID: UUID?) async throws -> String {
        return "[]"
    }
    
    public func exportJSONFile(for sessionID: UUID?) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_export.json")
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    public func exportSummaryCSV() async -> String {
        return ResearchSessionMetrics.summaryCSVHeader + "\n"
    }
    
    public func exportSummaryCSVFile() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("mock_summary.csv")
        try await exportSummaryCSV().write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Developer Documentation & Usage Examples

/*
 =========================================================================================
 ASSEMBLEAI RESEARCH TELEMETRY SYSTEM DEVELOPER GUIDE
 =========================================================================================
 
 1. HOW TO START A RESEARCH SESSION:
 ----------------------------------
 let sessionID = await ResearchLogger.shared.startResearchSession(
     projectID: "chair_assembly_task_1",
     strategy: .lastNFrames,
     lastNFrames: 5,
     mode: .liveTutor
 )
 
 2. HOW TO LOG EVENTS DURING AN EXPERIMENT:
 ------------------------------------------
 await ResearchLogger.shared.logEvent(ResearchEvent(
     sessionID: sessionID,
     projectID: projectUUID,
     stepID: stepUUID,
     mode: .liveTutor,
     eventType: .verificationCorrect,
     durationMilliseconds: 42,
     verificationStatus: "correct",
     metadata: [
         "input_tokens": "1420",
         "output_tokens": "38",
         "frames_processed": "5",
         "frames_in_context": "5"
     ]
 ))
 
 3. HOW TO FINISH A SESSION:
 ---------------------------
 // Optionally pass measured Joules / external power monitor energy cost:
 let metrics = await ResearchLogger.shared.endResearchSession(
     sessionID: sessionID,
     externalBatteryCost: 12.45 // e.g., Measured with Xcode Energy Gauge or Monsoon Power Monitor
 )
 
 4. HOW TO CALCULATE METRICS:
 ----------------------------
 let metrics = await ResearchLogger.shared.calculateMetrics(for: sessionID)
 print("Accuracy: \(metrics.verificationAccuracy ?? 0.0)")
 print("False Completion Rate: \(metrics.falseCompletionRate ?? 0.0)")
 print("Missed Completion Rate: \(metrics.missedCompletionRate ?? 0.0)")
 print("Temporal Consistency: \(metrics.temporalConsistency ?? 0.0)")
 print("Total Tokens: \(metrics.totalTokens ?? 0)")
 print("Peak Memory: \(metrics.peakMemoryMB ?? 0.0) MB")
 
 5. HOW TO EXPORT ONE SESSION:
 -----------------------------
 let sessionEventsCSVURL = try await ResearchLogger.shared.exportCSVFile(for: sessionID)
 let sessionEventsJSONURL = try await ResearchLogger.shared.exportJSONFile(for: sessionID)
 
 6. HOW TO EXPORT ALL SESSIONS:
 ------------------------------
 // Summary CSV (1 row per session - perfect for statistical analysis in Python/pandas, R, Excel):
 let summaryCSVURL = try await ResearchLogger.shared.exportSummaryCSVFile()
 
 // Full Event-Level CSV for all sessions:
 let allEventsCSVURL = try await ResearchLogger.shared.exportCSVFile()
 
 7. WHERE EXPORTED FILES ARE STORED:
 -----------------------------------
 Persisted local telemetry data:
   <App_Container>/Library/Application Support/ResearchData/
     ├── events.jsonl    (append-only event log; resilient to app crashes)
     └── sessions.json   (session configurations and lifecycle bounds)
 
 Shareable export files:
   <App_Container>/Documents/ResearchExports/
     ├── AssembleAI_Research_Summary_2026-09-04.csv
     ├── AssembleAI_Research_AllSessions_2026-09-04.csv
     └── AssembleAI_Research_Session_<UUID>.csv
 
 8. HOW TO GET THE EXPORT URL FOR SHARING:
 -----------------------------------------
 let summaryURL = try await ResearchLogger.shared.exportSummaryCSVFile()
 // Present natively in SwiftUI or UIKit:
 let activityVC = UIActivityViewController(activityItems: [summaryURL], applicationActivities: nil)
 
 =========================================================================================
 */
