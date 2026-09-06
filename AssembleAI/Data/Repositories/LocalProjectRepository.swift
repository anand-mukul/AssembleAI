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
@MainActor
final class LocalFirstProjectRepository: LocalProjectRepository {
    private let modelContext: ModelContext
    private let supabaseService: SupabaseProjectService?
    
    init(modelContext: ModelContext, supabaseService: SupabaseProjectService? = nil) {
        self.modelContext = modelContext
        self.supabaseService = supabaseService
    }
    
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

// MARK: - ProjectRepository Conformance

extension LocalFirstProjectRepository: ProjectRepository {
    
    /// Fetches all assembly projects from Supabase database with SwiftData local caching.
    func fetchProjects() async throws -> [AssemblyProject] {
        // Sync with Supabase if available
        if let supabaseService = supabaseService {
            do {
                let remoteProjects = try await supabaseService.fetchFullAssemblyProjects()
                if !remoteProjects.isEmpty {
                    // Update SwiftData cache with the remote projects
                    for remote in remoteProjects {
                        let targetId = remote.id
                        let fetchLocal = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == targetId })
                        if let existing = try? modelContext.fetch(fetchLocal).first {
                            existing.title = remote.title
                            existing.projectDescription = remote.description
                            existing.difficulty = remote.difficulty.rawValue
                            existing.estimatedMinutes = remote.estimatedMinutes
                            existing.thumbnailPath = remote.imageName
                            existing.updatedAt = Date()
                            existing.syncStateRaw = SyncState.synced.rawValue
                        } else {
                            let newLocal = LocalProject(
                                id: remote.id,
                                ownerId: remote.id,
                                title: remote.title,
                                projectDescription: remote.description,
                                difficulty: remote.difficulty.rawValue,
                                estimatedMinutes: remote.estimatedMinutes,
                                thumbnailPath: remote.imageName,
                                syncStateRaw: SyncState.synced.rawValue
                            )
                            modelContext.insert(newLocal)
                        }
                    }
                    try? modelContext.save()
                    return remoteProjects
                }
            } catch {
                // Offline fallback: fall through to local SwiftData cache
            }
        }
        
        // Query local SwiftData cache
        let descriptor = FetchDescriptor<LocalProject>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let localProjects = (try? modelContext.fetch(descriptor)) ?? []
        
        return localProjects.map { local in
            let pid = local.id
            let stepDesc = FetchDescriptor<LocalAssemblyStep>(
                predicate: #Predicate<LocalAssemblyStep> { $0.projectId == pid },
                sortBy: [SortDescriptor(\.stepOrder, order: .asc)]
            )
            let steps = (try? modelContext.fetch(stepDesc)) ?? []
            let domainSteps = steps.map { step in
                ProjectStepSummary(
                    id: step.id,
                    stepOrder: step.stepOrder,
                    title: step.title,
                    instruction: step.instruction,
                    expectedDurationMinutes: 0,
                    visualContract: step.toDomainModel().visualContract,
                    commonMistakes: []
                )
            }
            
            return AssemblyProject(
                id: local.id,
                title: local.title,
                subtitle: local.projectDescription,
                category: "Electronics",
                difficulty: Difficulty(rawValue: local.difficulty) ?? .beginner,
                estimatedMinutes: local.estimatedMinutes,
                totalSteps: domainSteps.count,
                completedSteps: 0,
                imageName: local.thumbnailPath,
                isActive: false,
                nextAction: nil,
                description: local.projectDescription,
                components: [],
                steps: domainSteps
            )
        }
    }
    
    /// Fetches recent user assembly activity from real recorded sessions.
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        guard !sessions.isEmpty else { return [] }
        
        let allProjects = (try? await (self as ProjectRepository).fetchProjects()) ?? []
        let projectMap = Dictionary(uniqueKeysWithValues: allProjects.map { ($0.id, $0.title) })
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        
        return sessions.prefix(5).map { session in
            let title = projectMap[session.projectId] ?? "Assembly Task"
            let timeStr = relativeFormatter.localizedString(for: session.updatedAt, relativeTo: Date())
            let isComplete = session.statusRaw == SessionStatus.completed.rawValue
            return ActivityItemModel(
                id: session.id,
                stepOrder: session.currentStepOrder,
                projectTitle: title,
                timestampDescription: "\(isComplete ? "Completed" : "Step \(session.currentStepOrder)") • \(timeStr)",
                iconName: isComplete ? "checkmark.circle.fill" : "wrench.fill"
            )
        }
    }
    
    /// Fetches a single project by ID.
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let projects: [AssemblyProject] = try await (self as ProjectRepository).fetchProjects()
        return projects.first { $0.id == id }
    }
}
