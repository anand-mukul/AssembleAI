//
//  ResearchSessionDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.research_sessions`.
//

import Foundation

/// PostgREST DTO representation of `public.research_sessions`.
struct ResearchSessionDTO: Codable, Sendable {
    var id: UUID?
    var userId: UUID?
    var sessionId: UUID
    var projectId: String?
    var mode: String?
    var visualStrategy: String?
    var strategyName: String?
    var lastNFrames: Int?
    var taskCompletionSeconds: Double?
    var completedStepsCount: Int?
    var totalVerificationAttempts: Int?
    var errorCount: Int?
    var uncertainCount: Int?
    var totalCorrectionSeconds: Double?
    var interventionCount: Int?
    var userQuestionCount: Int?
    var nominalCount: Int?
    var ePolCount: Int?
    var eSubCount: Int?
    var eOffCount: Int?
    var eSeatCount: Int?
    var verificationAccuracyPct: Double?
    var avgLatencyMs: Double?
    var peakMemoryMB: Double?
    var deviceModel: String?
    var osVersion: String?
    var startedAt: Date
    var endedAt: Date
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case projectId = "project_id"
        case mode
        case visualStrategy = "visual_strategy"
        case strategyName = "strategy_name"
        case lastNFrames = "last_n_frames"
        case taskCompletionSeconds = "task_completion_seconds"
        case completedStepsCount = "completed_steps_count"
        case totalVerificationAttempts = "total_verification_attempts"
        case errorCount = "error_count"
        case uncertainCount = "uncertain_count"
        case totalCorrectionSeconds = "total_correction_seconds"
        case interventionCount = "intervention_count"
        case userQuestionCount = "user_question_count"
        case nominalCount = "nominal_count"
        case ePolCount = "e_pol_count"
        case eSubCount = "e_sub_count"
        case eOffCount = "e_off_count"
        case eSeatCount = "e_seat_count"
        case verificationAccuracyPct = "verification_accuracy_pct"
        case avgLatencyMs = "avg_latency_ms"
        case peakMemoryMB = "peak_memory_mb"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
    }
}
