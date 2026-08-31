//
//  HomeViewModel.swift
//  AssembleAI
//

import Foundation
import Combine

/// View model managing state, active project retrieval, and recent activity for the Home screen.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var activeProject: AssemblyProject? = nil
    @Published private(set) var recentProjects: [AssemblyProject] = []
    @Published private(set) var recentActivity: [ActivityItemModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let repository: ProjectRepository
    
    init(repository: ProjectRepository? = nil) {
        self.repository = repository ?? ProjectRepositoryFactory.resolve()
    }
    
    /// Dynamic greeting string based on current hour of the day.
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    /// Loads active project, recent projects, and activity.
    func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let projectsTask = repository.fetchProjects()
            async let activityTask = repository.fetchRecentActivity()
            
            let allProjects = try await projectsTask
            let activities = try await activityTask
            
            self.activeProject = allProjects.first(where: { $0.isActive })
            self.recentProjects = Array(allProjects.filter { !$0.isActive }.prefix(3))
            self.recentActivity = activities
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
