//
//  BundledProjectRepository.swift
//  AssembleAI
//

import Foundation

/// Production project repository that loads project packages from JSON files.
///
/// Loading priority:
/// 1. User-downloaded projects from documents directory (highest priority, newest data).
/// 2. App bundle projects shipped with the application.
/// 3. Merged and deduplicated by project ID.
///
/// This replaces `MockProjectRepository` for production use while preserving
/// the same `ProjectRepository` protocol contract.
struct BundledProjectRepository: ProjectRepository {
    
    /// Optional bundle subdirectory name containing project JSON files.
    private let bundleDirectory: String
    
    /// Whether to also load user projects from the documents directory.
    private let includeUserProjects: Bool
    
    init(bundleDirectory: String = "Projects", includeUserProjects: Bool = true) {
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
        
        // Sort: active projects first, then by title
        return projects.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
    
    /// Synchronous access to bundled projects for AppIntents, Spotlight, and Siri queries.
    public static var bundledProjects: [AssemblyProject] {
        let loaded = ProjectPackageLoader.loadAllFromBundle(directory: "Projects")
        if loaded.isEmpty {
            return MockProjectData.sampleProjects
        }
        return loaded
    }
    
    @MainActor
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        let repo = LocalFirstSessionRepository(modelContext: PersistenceController.shared.container.mainContext)
        guard let sessions = try? await repo.fetchAllSessions(), !sessions.isEmpty else {
            return []
        }
        
        let projects = (try? await fetchProjects()) ?? []
        let projectMap = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.title) })
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        
        return sessions.prefix(5).map { session in
            let title = projectMap[session.projectId] ?? "Assembly Task"
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
