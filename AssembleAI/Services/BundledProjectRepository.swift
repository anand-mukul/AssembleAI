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
    
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        // In production, this will be driven by SwiftData session records.
        // For now, return empty; the HomeView gracefully handles an empty state.
        return []
    }
    
    /// Fetches a single project by ID from all available sources.
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let projects = try await fetchProjects()
        return projects.first { $0.id == id }
    }
}
