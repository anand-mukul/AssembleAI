//
//  BundledProjectRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData

/// Production project repository that loads project packages from JSON files.
///
/// Loading priority:
/// 1. User-downloaded projects from documents directory (highest priority, newest data).
/// 2. App bundle projects shipped with the application.
/// 3. Merged and deduplicated by project ID.
///
/// This replaces `MockProjectRepository` for production use while preserving
/// the same `ProjectRepository` protocol contract.
nonisolated struct BundledProjectRepository: ProjectRepository, Sendable {
    
    /// Optional bundle subdirectory name containing project JSON files.
    private let bundleDirectory: String
    
    /// Whether to also load user projects from the documents directory.
    private let includeUserProjects: Bool
    
    nonisolated init(bundleDirectory: String = "Projects", includeUserProjects: Bool = true) {
        self.bundleDirectory = bundleDirectory
        self.includeUserProjects = includeUserProjects
    }
    
    func fetchProjects() async throws -> [AssemblyProject] {
        // Load from bundle (shipped with the app)
        var projects = ProjectPackageLoader.loadAllFromBundle(directory: bundleDirectory)
        
        // Merge user-downloaded projects from documents
        if includeUserProjects {
            let userProjects = ProjectPackageLoader.loadAllFromDocuments()
            let existingIds = Set(projects.map(\.id))
            
            for userProject in userProjects {
                if existingIds.contains(userProject.id) {
                    // User version overrides bundled version
                    projects.removeAll { $0.id == userProject.id }
                }
                projects.append(userProject)
            }
        }
        
        // Enrich projects with persisted session progress
        projects = await enrichProjectsWithSessions(projects)
        
        // Sort: active projects first, then most recently worked on, then alphabetical by title
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
    
    @MainActor
    private func enrichProjectsWithSessions(_ projects: [AssemblyProject]) async -> [AssemblyProject] {
        let repo = LocalFirstSessionRepository(modelContext: PersistenceController.shared.container.mainContext)
        guard let sessions = try? await repo.fetchAllSessions(), !sessions.isEmpty else {
            return projects
        }
        
        // Latest session per project ID or matching title
        var latestSessionByProject: [UUID: AssemblySession] = [:]
        for session in sessions {
            if let existing = latestSessionByProject[session.projectId] {
                if session.updatedAt > existing.updatedAt {
                    latestSessionByProject[session.projectId] = session
                }
            } else {
                latestSessionByProject[session.projectId] = session
            }
        }
        
        return projects.map { project in
            let matchingSession = latestSessionByProject[project.id] ?? sessions.first { session in
                if let title = session.projectTitle, !title.isEmpty,
                   title.localizedCaseInsensitiveCompare(project.title) == .orderedSame {
                    return true
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
    
    /// Synchronous access to bundled projects for AppIntents, Spotlight, and Siri queries.
    public nonisolated static var bundledProjects: [AssemblyProject] {
        ProjectPackageLoader.loadAllFromBundle(directory: "Projects")
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
    
    /// Fetches a single project by ID from all available sources.
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let projects = try await fetchProjects()
        return projects.first { $0.id == id }
    }
}
