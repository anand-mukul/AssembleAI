//
//  ResearchCloudSyncService.swift
//  AssembleAI
//
//  Autonomous background telemetry service for AssembleAI empirical evaluations.
//  Streams session benchmarks, step accuracy, resident memory, and latency profiling
//  directly to cloud endpoints (Google Sheets Webhook, Airtable, PostHog, or Supabase)
//  eliminating manual CSV/JSON downloads for research papers.
//

import Foundation

/// Autonomous background service that syncs research evaluation sessions and metrics to cloud endpoints.
actor ResearchCloudSyncService {
    static let shared = ResearchCloudSyncService()
    
    // Status tracking for UI indicators
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date? = nil
    private(set) var lastSyncError: String? = nil
    private(set) var totalSessionsSynced: Int = 0
    
    // Local offline queue file
    private let pendingQueueURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("ResearchData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.pendingQueueURL = dir.appendingPathComponent("pending_cloud_sync.json")
    }
    
    // MARK: - Primary Public API
    
    /// Synchronizes a completed research session metrics record to the cloud.
    /// - Parameters:
    ///   - metrics: Comprehensive computed session benchmarks.
    ///   - config: Session configuration and device hardware profile.
    func syncSessionMetrics(
        metrics: ResearchSessionMetrics,
        config: ResearchSessionConfig?
    ) async {
        let payload = buildTabularPayload(metrics: metrics, config: config)
        await dispatchPayload(payload)
    }
    
    /// Flushes any pending offline payloads that failed to sync during previous runs.
    func flushPendingQueue() async {
        let pending = loadPendingPayloads()
        guard !pending.isEmpty else { return }
        
        var remaining: [[String: Any]] = []
        for item in pending {
            let success = await sendToDestination(item)
            if !success {
                remaining.append(item)
            } else {
                totalSessionsSynced += 1
            }
        }
        savePendingPayloads(remaining)
        if remaining.isEmpty {
            lastSyncDate = Date()
            lastSyncError = nil
        }
    }
    
    /// Returns the number of payloads currently waiting in the offline retry queue.
    func getPendingQueueCount() -> Int {
        loadPendingPayloads().count
    }
    
    // MARK: - Tabular Formatting (Research Paper & Spreadsheet Aligned)
    
    /// Formats the session metrics into a flat, standardized dictionary ready for
    /// Google Sheets rows, Airtable bases, or statistical analysis (Pandas / R).
    private func buildTabularPayload(
        metrics: ResearchSessionMetrics,
        config: ResearchSessionConfig?
    ) -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()
        
        let startStr = metrics.startedAt.map { isoFormatter.string(from: $0) } ?? isoFormatter.string(from: now)
        let endStr = metrics.endedAt.map { isoFormatter.string(from: $0) } ?? isoFormatter.string(from: now)
        
        var row: [String: Any] = [
            "schema_version": metrics.schemaVersion,
            "session_id": metrics.sessionID.uuidString,
            "project_id": metrics.projectID,
            "mode": metrics.mode.rawValue,
            "visual_strategy": metrics.strategy.rawValue,
            "strategy_name": metrics.strategy.displayName,
            "last_n_frames": metrics.lastNFrames ?? 0,
            "timestamp": startStr,
            "ended_at": endStr,
            "device_model": metrics.deviceModel,
            "os_version": metrics.iosVersion,
            
            // Progression & Temporal Duration
            "task_completion_seconds": round(metrics.taskCompletionTimeSeconds * 100) / 100,
            "completed_steps_count": metrics.completedStepsCount,
            "total_verification_attempts": metrics.totalVerificationAttempts,
            "error_count": metrics.errorCount,
            "uncertain_count": metrics.uncertainCount,
            "total_correction_seconds": round(metrics.totalCorrectionTimeSeconds * 100) / 100,
            "intervention_count": metrics.interventionCount,
            "user_question_count": metrics.userQuestionCount,
            
            // Empirical Accuracy & Error Rates
            "verification_accuracy_pct": metrics.verificationAccuracy != nil ? round(metrics.verificationAccuracy! * 1000) / 10 : 0.0,
            "false_completion_rate": metrics.falseCompletionRate != nil ? round(metrics.falseCompletionRate! * 1000) / 1000 : 0.0,
            "missed_completion_rate": metrics.missedCompletionRate != nil ? round(metrics.missedCompletionRate! * 1000) / 1000 : 0.0,
            "temporal_consistency": metrics.temporalConsistency != nil ? round(metrics.temporalConsistency! * 1000) / 1000 : 0.0,
            
            // Token Consumption
            "total_tokens": metrics.totalTokens ?? 0,
            "total_input_tokens": metrics.totalInputTokens ?? 0,
            "total_output_tokens": metrics.totalOutputTokens ?? 0,
            
            // Latency Benchmarks (Milliseconds)
            "avg_latency_ms": metrics.avgLatencyMs,
            "total_latency_ms": metrics.totalLatencyMs,
            "avg_verification_latency_ms": metrics.avgVerificationLatencyMs,
            "avg_model_latency_ms": metrics.avgModelLatencyMs,
            "avg_speech_latency_ms": metrics.avgSpeechLatencyMs,
            "avg_progression_latency_ms": metrics.avgProgressionLatencyMs,
            "avg_intervention_latency_ms": metrics.avgInterventionLatencyMs,
            
            // Computational & Resident Memory (MB)
            "memory_before_mb": metrics.memoryBeforeMB != nil ? round(metrics.memoryBeforeMB! * 10) / 10 : 0.0,
            "memory_after_mb": metrics.memoryAfterMB != nil ? round(metrics.memoryAfterMB! * 10) / 10 : 0.0,
            "peak_memory_mb": metrics.peakMemoryMB != nil ? round(metrics.peakMemoryMB! * 10) / 10 : 0.0,
            
            // Visual Frame Processing Pipeline
            "frames_received": metrics.framesReceived,
            "frames_processed": metrics.framesProcessed,
            "frames_included_in_context": metrics.framesIncludedInModelContext,
            "frames_dropped": metrics.framesDropped
        ]
        
        if let battery = metrics.batteryCost {
            row["battery_cost_pct"] = round(battery * 1000) / 10
        }
        
        return row
    }
    
    // MARK: - Dispatch Pipeline
    
    private func dispatchPayload(_ payload: [String: Any]) async {
        isSyncing = true
        let success = await sendToDestination(payload)
        isSyncing = false
        
        if success {
            totalSessionsSynced += 1
            lastSyncDate = Date()
            lastSyncError = nil
            // Attempt to flush any previously failed offline payloads
            await flushPendingQueue()
        } else {
            // Enqueue locally for offline safety
            var pending = loadPendingPayloads()
            pending.append(payload)
            savePendingPayloads(pending)
        }
    }
    
    private func sendToDestination(_ payload: [String: Any]) async -> Bool {
        // Priority 1: Third-Party Webhook (Google Sheets, Airtable, PostHog, or custom endpoint)
        if let webhookString = AppConfig.researchTelemetryWebhookURL,
           let url = URL(string: webhookString),
           url.scheme == "https" || url.scheme == "http" {
            let webhookSuccess = await postJSON(url: url, payload: payload)
            if webhookSuccess { return true }
        }
        
        // Priority 2: Supabase PostgREST backend (if configured)
        if AppConfig.isSupabaseConfigured {
            let supabaseSuccess = await postToSupabase(payload: payload)
            if supabaseSuccess { return true }
        }
        
        return false
    }
    
    private func postJSON(url: URL, payload: [String: Any]) async -> Bool {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("AssembleAI-iOS-Research/\(AppConfig.appVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...399).contains(httpResponse.statusCode) {
                return true
            }
            return false
        } catch {
            self.lastSyncError = error.localizedDescription
            return false
        }
    }
    
    private func postToSupabase(payload: [String: Any]) async -> Bool {
        guard AppConfig.isSupabaseConfigured,
              let url = URL(string: "\(AppConfig.supabaseUrl)/rest/v1/research_sessions"),
              url.scheme == "https" else { return false }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.timeoutInterval = 15
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Offline Storage Queue
    
    private func loadPendingPayloads() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: pendingQueueURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }
    
    private func savePendingPayloads(_ payloads: [[String: Any]]) {
        if payloads.isEmpty {
            try? FileManager.default.removeItem(at: pendingQueueURL)
        } else if let data = try? JSONSerialization.data(withJSONObject: payloads, options: [.prettyPrinted]) {
            try? data.write(to: pendingQueueURL, options: .atomic)
        }
    }
}
