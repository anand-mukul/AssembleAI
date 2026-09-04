//
//  LocalProjectRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData
import Combine

protocol LocalProjectRepository: Sendable {
    func fetchProjects() async throws -> [Project]
    func fetchProject(id: UUID) async throws -> Project?
    func saveProject(_ project: Project) async throws
    func deleteProject(id: UUID) async throws
}

/// Local-first implementation querying SwiftData instantly and syncing with Supabase asynchronously.
final class LocalFirstProjectRepository: LocalProjectRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let supabaseService: SupabaseProjectService?
    
    init(modelContext: ModelContext, supabaseService: SupabaseProjectService? = nil) {
        self.modelContext = modelContext
        self.supabaseService = supabaseService
    }
    
    @MainActor
    func fetchProjects() async throws -> [Project] {
        let descriptor = FetchDescriptor<LocalProject>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let localProjects = try modelContext.fetch(descriptor)
        let domainProjects = localProjects.map { $0.toDomainModel() }
        
        // Asynchronously sync from Supabase if available
        if let supabaseService = supabaseService {
            Task { @MainActor in
                do {
                    let remoteProjects = try await supabaseService.fetchProjects()
                    for remote in remoteProjects {
                        let targetId = remote.id
                        let fetchLocal = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == targetId })
                        if let existing = try self.modelContext.fetch(fetchLocal).first {
                            existing.title = remote.title
                            existing.projectDescription = remote.description
                            existing.difficulty = remote.difficulty
                            existing.estimatedMinutes = remote.estimatedMinutes
                            existing.thumbnailPath = remote.thumbnailPath
                            existing.updatedAt = remote.updatedAt
                            existing.syncStateRaw = SyncState.synced.rawValue
                        } else {
                            let newLocal = LocalProject.fromDomainModel(remote)
                            newLocal.syncStateRaw = SyncState.synced.rawValue
                            self.modelContext.insert(newLocal)
                        }
                    }
                    try self.modelContext.save()
                } catch {
                    // Offline fallback
                }
            }
        }
        
        return domainProjects
    }
    
    @MainActor
    func fetchProject(id: UUID) async throws -> Project? {
        do {
            let fetchLocal = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == id })
            if let local = try modelContext.fetch(fetchLocal).first {
                return local.toDomainModel()
            }
            return nil
        } catch {
            throw AppError.database(error.localizedDescription)
        }
    }
    
    @MainActor
    func saveProject(_ project: Project) async throws {
        let targetId = project.id
        let fetchLocal = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == targetId })
        
        do {
            if let existing = try modelContext.fetch(fetchLocal).first {
                existing.title = project.title
                existing.projectDescription = project.description
                existing.difficulty = project.difficulty
                existing.estimatedMinutes = project.estimatedMinutes
                existing.thumbnailPath = project.thumbnailPath
                existing.updatedAt = Date()
                existing.syncStateRaw = SyncState.pendingUpload.rawValue
            } else {
                let localProject = LocalProject.fromDomainModel(project)
                localProject.syncStateRaw = SyncState.pendingUpload.rawValue
                modelContext.insert(localProject)
            }
            
            try modelContext.save()
        } catch {
            throw AppError.database(error.localizedDescription)
        }
        
        // Background push to Supabase if available
        if let supabaseService = supabaseService {
            Task { @MainActor in
                do {
                    try await supabaseService.saveProject(project)
                    if let existing = try self.modelContext.fetch(fetchLocal).first {
                        existing.syncStateRaw = SyncState.synced.rawValue
                        try self.modelContext.save()
                    }
                } catch {
                    // Retain pendingUpload state for sync coordinator retry
                }
            }
        }
    }
    
    @MainActor
    func deleteProject(id: UUID) async throws {
        do {
            let fetchLocal = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == id })
            if let existing = try modelContext.fetch(fetchLocal).first {
                modelContext.delete(existing)
                try modelContext.save()
            }
        } catch {
            throw AppError.database(error.localizedDescription)
        }
        
        if let supabaseService = supabaseService {
            Task {
                try? await supabaseService.deleteProject(id: id)
            }
        }
    }
}
