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
    func syncWithCloud() async -> SyncEvent
}

@MainActor
final class LocalFirstSessionRepository: SessionRepository {
    private let modelContext: ModelContext
    private let syncEngine: CloudSyncEngine
    
    init(
        modelContext: ModelContext,
        syncEngine: CloudSyncEngine? = nil
    ) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine ?? CloudSyncEngine(backend: SupabaseCloudSyncBackend())
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
            if let title = session.projectTitle {
                existing.projectTitle = title
            }
            existing.syncStateRaw = SyncState.pendingUpload.rawValue
            existing.updatedAt = Date()
        } else {
            var localDomain = session
            localDomain.syncState = .pendingUpload
            let localSession = LocalAssemblySession.fromDomainModel(localDomain)
            modelContext.insert(localSession)
        }
        
        try modelContext.save()
        
        // Asynchronously trigger cloud synchronization in the background
        if AppConfig.isSupabaseConfigured {
            Task { [weak self] in
                _ = await self?.syncWithCloud()
            }
        }
    }
    
    @discardableResult
    func syncWithCloud() async -> SyncEvent {
        guard AppConfig.isSupabaseConfigured else {
            return .syncCompleted(recordsUploaded: 0, recordsDownloaded: 0)
        }
        
        let descriptor = FetchDescriptor<LocalAssemblySession>()
        guard let localEntities = try? modelContext.fetch(descriptor) else {
            return .syncFailed(errorDescription: "Unable to read local SwiftData sessions.")
        }
        
        let localDomain = localEntities.map { $0.toDomainModel() }
        let (synced, event) = await syncEngine.synchronizeSessions(localSessions: localDomain)
        
        // Reconcile synced / updated sessions back into SwiftData
        for session in synced {
            let targetId = session.id
            let fetchLocal = FetchDescriptor<LocalAssemblySession>(predicate: #Predicate<LocalAssemblySession> { $0.id == targetId })
            if let existing = try? modelContext.fetch(fetchLocal).first {
                existing.statusRaw = session.status.rawValue
                existing.currentStepOrder = session.currentStepOrder
                existing.completedAt = session.completedAt
                existing.syncStateRaw = session.syncState.rawValue
                existing.updatedAt = session.updatedAt
                if let title = session.projectTitle {
                    existing.projectTitle = title
                }
            } else {
                let newLocal = LocalAssemblySession.fromDomainModel(session)
                modelContext.insert(newLocal)
            }
        }
        
        try? modelContext.save()
        return event
    }
}
