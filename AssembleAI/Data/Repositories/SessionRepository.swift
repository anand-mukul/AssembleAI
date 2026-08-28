//
//  SessionRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData

protocol SessionRepository: Sendable {
    func fetchSessions(userId: UUID) async throws -> [AssemblySession]
    func fetchSession(id: UUID) async throws -> AssemblySession?
    func saveSession(_ session: AssemblySession) async throws
}

final class LocalFirstSessionRepository: SessionRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func fetchSessions(userId: UUID) async throws -> [AssemblySession] {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let localSessions = try modelContext.fetch(descriptor)
        return localSessions.map { $0.toDomainModel() }
    }
    
    @MainActor
    func fetchSession(id: UUID) async throws -> AssemblySession? {
        let fetchLocal = FetchDescriptor<LocalAssemblySession>(predicate: #Predicate<LocalAssemblySession> { $0.id == id })
        return try modelContext.fetch(fetchLocal).first?.toDomainModel()
    }
    
    @MainActor
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
    }
}
