//
//  SupabaseCloudSyncBackend.swift
//  AssembleAI
//
//  Production CloudSyncBackend backed by Supabase PostgREST.
//

import Foundation

/// Production CloudSyncBackend implementation bridging CloudSyncEngine to Supabase.
final class SupabaseCloudSyncBackend: CloudSyncBackend, Sendable {
    private let projectService: SupabaseProjectService
    
    init(projectService: SupabaseProjectService = SupabaseProjectService(supabaseManager: SupabaseManager.shared)) {
        self.projectService = projectService
    }
    
    func uploadSessions(_ sessions: [AssemblySession]) async throws -> [AssemblySession] {
        guard AppConfig.isSupabaseConfigured else {
            return sessions
        }
        return try await projectService.saveSessions(sessions)
    }
    
    func fetchRemoteSessions(since: Date?) async throws -> [AssemblySession] {
        guard AppConfig.isSupabaseConfigured else {
            return []
        }
        return try await projectService.fetchSessions(since: since)
    }
    
    func deleteRemoteSession(id: UUID) async throws {
        guard AppConfig.isSupabaseConfigured else { return }
        try await projectService.deleteSession(id: id)
    }
}
