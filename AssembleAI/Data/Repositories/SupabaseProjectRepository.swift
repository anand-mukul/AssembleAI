//
//  SupabaseProjectRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData

/// Production repository that queries Supabase PostgreSQL for assembly projects,
/// falling back seamlessly to local bundled project packages when offline or unreachable.
struct SupabaseProjectRepository: ProjectRepository {
    private let supabaseService: SupabaseProjectService
    private let fallbackRepository: BundledProjectRepository
    
    init(
        supabaseService: SupabaseProjectService,
        fallbackRepository: BundledProjectRepository = BundledProjectRepository()
    ) {
        self.supabaseService = supabaseService
        self.fallbackRepository = fallbackRepository
    }
    
    @MainActor
    init(fallbackRepository: BundledProjectRepository = BundledProjectRepository()) {
        self.supabaseService = SupabaseProjectService(supabaseManager: SupabaseManager.shared)
        self.fallbackRepository = fallbackRepository
    }
    
    func fetchProjects() async throws -> [AssemblyProject] {
        var projects: [AssemblyProject] = []
        if AppConfig.isSupabaseConfigured {
            do {
                let remote = try await supabaseService.fetchFullAssemblyProjects()
                if !remote.isEmpty {
                    projects = remote
                }
            } catch {
                // Supabase unreachable or offline: fall through to bundled package loader
            }
        }
        if projects.isEmpty {
            projects = try await fallbackRepository.fetchProjects()
        }
        
        projects = await enrichProjectsWithSessions(projects)
        
        return projects.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            if let lDate = lhs.lastWorkedOn, let rDate = rhs.lastWorkedOn {
                return lDate > rDate
            }
            if lhs.lastWorkedOn != nil { return true }
            if rhs.lastWorkedOn != nil { return false }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
    
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let projects = try await fetchProjects()
        return projects.first { $0.id == id }
    }
    
    @MainActor
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        let repo = LocalFirstSessionRepository(modelContext: PersistenceController.shared.container.mainContext)
        guard let sessions = try? await repo.fetchAllSessions(), !sessions.isEmpty else {
            return []
        }
        
        let projects = (try? await fetchProjects()) ?? []
        let projectMap = Dictionary(projects.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        
        return sessions.prefix(5).map { session in
            let title = session.projectTitle ?? projectMap[session.projectId] ?? "Assembly Task"
            let timeStr = relativeFormatter.localizedString(for: session.updatedAt, relativeTo: Date())
            let isComplete = session.status == .completed
            return ActivityItemModel(
                id: session.id,
                stepOrder: session.currentStepOrder,
                projectTitle: title,
                timestampDescription: "\(isComplete ? "Completed" : "Step \(session.currentStepOrder)") • \(timeStr)",
                iconName: isComplete ? "checkmark.circle.fill" : "wrench.fill"
            )
        }
    }
    
    @MainActor
    private func enrichProjectsWithSessions(_ projects: [AssemblyProject]) async -> [AssemblyProject] {
        let repo = LocalFirstSessionRepository(modelContext: PersistenceController.shared.container.mainContext)
        guard let sessions = try? await repo.fetchAllSessions(), !sessions.isEmpty else {
            return projects
        }
        
        let bundled = BundledProjectRepository.bundledProjects
        
        return projects.map { project in
            let matchingSession = sessions.first { session in
                if session.projectId == project.id { return true }
                if let title = session.projectTitle, !title.isEmpty,
                   title.localizedCaseInsensitiveCompare(project.title) == .orderedSame {
                    return true
                }
                if let bundledMatch = bundled.first(where: { $0.id == session.projectId }) {
                    return bundledMatch.title.localizedCaseInsensitiveCompare(project.title) == .orderedSame
                }
                return false
            }
            
            guard let session = matchingSession else {
                return project
            }
            
            let isCompleted = session.status == .completed || session.completedSteps.count >= project.totalSteps
            let completedCount = min(project.totalSteps, max(session.completedSteps.count, max(0, session.currentStepOrder - 1)))
            let isActive = !isCompleted && (session.status == .inProgress || completedCount > 0)
            
            let nextActionText: String = {
                if isCompleted {
                    return "Completed"
                }
                let nextIndex = completedCount
                if nextIndex < project.steps.count {
                    return project.steps[nextIndex].title
                }
                return "Step \(completedCount + 1)"
            }()
            
            return AssemblyProject(
                id: project.id,
                title: project.title,
                subtitle: project.subtitle,
                category: project.category,
                difficulty: project.difficulty,
                estimatedMinutes: project.estimatedMinutes,
                totalSteps: project.totalSteps,
                completedSteps: completedCount,
                imageName: project.imageName,
                isActive: isActive,
                nextAction: nextActionText,
                description: project.description,
                components: project.components,
                steps: project.steps,
                domain: project.domain,
                lastWorkedOn: session.updatedAt
            )
        }
    }
}
