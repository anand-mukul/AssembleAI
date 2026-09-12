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
    
    // Deduplication tracking
    private var lastSyncedSessionID: UUID? = nil
    private var lastSyncedTimestamp: Date? = nil
    
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
        // Debounce rapid duplicate dispatches for the exact same session within 2 seconds
        if lastSyncedSessionID == metrics.sessionID,
           let lastTime = lastSyncedTimestamp,
           abs(Date().timeIntervalSince(lastTime)) < 2.0 {
            return
        }
        lastSyncedSessionID = metrics.sessionID
        lastSyncedTimestamp = Date()
        
        let payload = buildTabularPayload(metrics: metrics, config: config)
        await dispatchPayload(payload)
    }
    
    /// Sends a verified test telemetry ping to confirm endpoint connectivity (e.g. Google Apps Script).
    func sendTestPayload(to urlString: String) async -> (success: Bool, message: String) {
        guard let url = URL(string: urlString),
              url.scheme == "https" || url.scheme == "http" else {
            return (false, "Invalid URL schema. Must start with https:// or http://")
        }
        
        let testPayload: [String: Any] = [
            "event": "webhook_connection_test",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "message": "AssembleAI Research Telemetry Webhook Connection Verified",
            "app_version": AppConfig.appVersion,
            "device_model": ResearchLogger.getDeviceModelIdentifier(),
            "status": "ready"
        ]
        
        let success = await postJSON(url: url, payload: testPayload)
        if success {
            return (true, "Webhook verified! Successfully connected to cloud endpoint.")
        } else {
            let err = self.lastSyncError ?? "Endpoint returned HTTP error status or timed out."
            return (false, "Connection failed: \(err)")
        }
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
        
        var row: [String: Any] = [:]
        
        // 1. Session Metadata & Configuration
        row["event"] = "research_session_completed"
        row["schema_version"] = metrics.schemaVersion
        row["session_id"] = metrics.sessionID.uuidString
        row["project_id"] = metrics.projectID
        row["mode"] = metrics.mode.rawValue
        row["visual_strategy"] = metrics.strategy.rawValue
        row["strategy_name"] = metrics.strategy.displayName
        row["last_n_frames"] = metrics.lastNFrames ?? 0
        row["timestamp"] = startStr
        row["ended_at"] = endStr
        row["device_model"] = metrics.deviceModel
        row["os_version"] = metrics.iosVersion
        
        // 2. Progression & Temporal Duration
        row["task_completion_seconds"] = round(metrics.taskCompletionTimeSeconds * 100) / 100
        row["completed_steps_count"] = metrics.completedStepsCount
        row["total_verification_attempts"] = metrics.totalVerificationAttempts
        row["error_count"] = metrics.errorCount
        row["uncertain_count"] = metrics.uncertainCount
        row["total_correction_seconds"] = round(metrics.totalCorrectionTimeSeconds * 100) / 100
        row["intervention_count"] = metrics.interventionCount
        row["user_question_count"] = metrics.userQuestionCount
        
        // 3. Error Taxonomy Breakdown (Paper Section V-B & Figure 1)
        row["nominal_count"] = metrics.nominalCount
        row["e_pol_count"] = metrics.ePolCount
        row["e_sub_count"] = metrics.eSubCount
        row["e_off_count"] = metrics.eOffCount
        row["e_seat_count"] = metrics.eSeatCount
        
        // 4. Empirical Accuracy & Error Rates
        row["verification_accuracy_pct"] = metrics.verificationAccuracy.map { round($0 * 1000) / 10 } ?? 0.0
        row["false_completion_rate"] = metrics.falseCompletionRate.map { round($0 * 1000) / 1000 } ?? 0.0
        row["missed_completion_rate"] = metrics.missedCompletionRate.map { round($0 * 1000) / 1000 } ?? 0.0
        row["temporal_consistency"] = metrics.temporalConsistency.map { round($0 * 1000) / 1000 } ?? 0.0
        
        // 5. Token Consumption
        row["total_tokens"] = metrics.totalTokens ?? 0
        row["total_input_tokens"] = metrics.totalInputTokens ?? 0
        row["total_output_tokens"] = metrics.totalOutputTokens ?? 0
        
        // 6. Latency Benchmarks (Milliseconds)
        row["avg_latency_ms"] = metrics.avgLatencyMs
        row["total_latency_ms"] = metrics.totalLatencyMs
        row["avg_verification_latency_ms"] = metrics.avgVerificationLatencyMs
        row["avg_model_latency_ms"] = metrics.avgModelLatencyMs
        row["avg_speech_latency_ms"] = metrics.avgSpeechLatencyMs
        row["avg_progression_latency_ms"] = metrics.avgProgressionLatencyMs
        row["avg_intervention_latency_ms"] = metrics.avgInterventionLatencyMs
        
        // 7. Computational & Resident Memory (MB)
        row["memory_before_mb"] = metrics.memoryBeforeMB.map { round($0 * 10) / 10 } ?? 0.0
        row["memory_after_mb"] = metrics.memoryAfterMB.map { round($0 * 10) / 10 } ?? 0.0
        row["peak_memory_mb"] = metrics.peakMemoryMB.map { round($0 * 10) / 10 } ?? 0.0
        if let battery = metrics.batteryCost {
            row["battery_cost_pct"] = round(battery * 1000) / 10
        }
        
        // 8. Visual Frame Processing Pipeline
        row["frames_received"] = metrics.framesReceived
        row["frames_processed"] = metrics.framesProcessed
        row["frames_included_in_context"] = metrics.framesIncludedInModelContext
        row["frames_dropped"] = metrics.framesDropped
        
        // 9. Convenience structures for Google Sheets / Excel auto-append scripts
        row["column_headers"] = ResearchSessionMetrics.summaryCSVHeader.components(separatedBy: ",")
        row["csv_row"] = metrics.summaryCSVLine
        row["csv_header"] = ResearchSessionMetrics.summaryCSVHeader
        row["row_values"] = metrics.tabularRowValues
        
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
