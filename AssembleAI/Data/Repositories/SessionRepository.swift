//
//  SessionRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData

protocol SessionRepository: Sendable {
    func fetchSessions(userId: UUID) async throws -> [AssemblySession]
    func fetchAllSessions() async throws -> [AssemblySession]
    func fetchSession(id: UUID) async throws -> AssemblySession?
    func fetchActiveSession(projectId: UUID) async throws -> AssemblySession?
    func pauseOtherActiveSessions(except projectId: UUID) async throws
    func saveSession(_ session: AssemblySession) async throws
}

@MainActor
final class LocalFirstSessionRepository: SessionRepository {
    private let modelContext: ModelContext
    private let supabaseService: SupabaseProjectService?
    
    init(modelContext: ModelContext, supabaseService: SupabaseProjectService? = nil) {
        self.modelContext = modelContext
        self.supabaseService = supabaseService
    }
    
    func fetchSessions(userId: UUID) async throws -> [AssemblySession] {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let localSessions = try modelContext.fetch(descriptor)
        return localSessions.map { $0.toDomainModel() }
    }
    
    func fetchAllSessions() async throws -> [AssemblySession] {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let localSessions = try modelContext.fetch(descriptor)
        return localSessions.map { $0.toDomainModel() }
    }
    
    func fetchSession(id: UUID) async throws -> AssemblySession? {
        let fetchLocal = FetchDescriptor<LocalAssemblySession>(predicate: #Predicate<LocalAssemblySession> { $0.id == id })
        return try modelContext.fetch(fetchLocal).first?.toDomainModel()
    }
    
    func fetchActiveSession(projectId: UUID) async throws -> AssemblySession? {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let localSessions = try modelContext.fetch(descriptor)
        return localSessions.first(where: { $0.statusRaw != SessionStatus.completed.rawValue })?.toDomainModel()
            ?? localSessions.first?.toDomainModel()
    }
    
    func pauseOtherActiveSessions(except projectId: UUID) async throws {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.projectId != projectId }
        )
        let otherSessions = try modelContext.fetch(descriptor)
        var modified = false
        for session in otherSessions {
            if session.statusRaw == SessionStatus.inProgress.rawValue {
                session.statusRaw = SessionStatus.paused.rawValue
                session.updatedAt = Date()
                modified = true
            }
        }
        if modified {
            try modelContext.save()
        }
    }
    
    func saveSession(_ session: AssemblySession) async throws {
        let targetId = session.id
        let fetchLocal = FetchDescriptor<LocalAssemblySession>(predicate: #Predicate<LocalAssemblySession> { $0.id == targetId })
        
        if let existing = try modelContext.fetch(fetchLocal).first {
            existing.statusRaw = session.status.rawValue
            existing.currentStepOrder = session.currentStepOrder
            existing.completedAt = session.completedAt
            existing.updatedAt = Date()
        } else {
            let localSession = LocalAssemblySession.fromDomainModel(session)
            modelContext.insert(localSession)
        }
        
        try modelContext.save()
        
        if let supabaseService = supabaseService {
            Task {
                try? await supabaseService.saveSession(session)
            }
        }
    }
}
