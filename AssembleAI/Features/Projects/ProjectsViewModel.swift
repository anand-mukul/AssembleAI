//
//  ProjectsViewModel.swift
//  AssembleAI
//

import Foundation
import Combine

/// Filter segment choices for the Projects list.
enum ProjectFilterTab: String, CaseIterable, Identifiable, Codable, Hashable, Equatable, Sendable {
    case all = "All"
    case inProgress = "In Progress"
    case completed = "Completed"
    
    var id: String { rawValue }
}

/// View model for project list filtering, search, and data loading.
@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFilter: ProjectFilterTab = .all
    @Published private(set) var allProjects: [AssemblyProject] = []
    @Published private(set) var isLoading: Bool = false
    @Published var showAddProjectSheet: Bool = false
    
    private let repository: ProjectRepository
    
    init(repository: ProjectRepository? = nil) {
        self.repository = repository ?? MockProjectRepository()
    }
    
    /// Filtered list of projects based on search query and selected filter segment.
    var filteredProjects: [AssemblyProject] {
        allProjects.filter { project in
            // Filter by search text (title or category)
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = project.title.lowercased().contains(query) ||
                                project.category.lowercased().contains(query) ||
                                project.subtitle.lowercased().contains(query)
            }
            
            // Filter by segment tab
            let matchesTab: Bool
            switch selectedFilter {
            case .all:
                matchesTab = true
            case .inProgress:
                matchesTab = !project.isCompleted && project.completedSteps > 0
            case .completed:
                matchesTab = project.isCompleted
            }
            
            return matchesSearch && matchesTab
        }
    }
    
    func loadProjects() async {
        isLoading = true
        do {
            self.allProjects = try await repository.fetchProjects()
            self.isLoading = false
        } catch {
            self.isLoading = false
        }
    }
}
