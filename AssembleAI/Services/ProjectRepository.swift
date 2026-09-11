//
//  ProjectRepository.swift
//  AssembleAI
//

import Foundation

/// Protocol for fetching and managing assembly projects.
protocol ProjectRepository: Sendable {
    /// Fetches all available projects.
    func fetchProjects() async throws -> [AssemblyProject]
    
    /// Fetches a single project by its unique identifier.
    func fetchProject(byId id: UUID) async throws -> AssemblyProject?
    
    /// Fetches recent step activity history.
    func fetchRecentActivity() async throws -> [ActivityItemModel]
}

/// Default implementation for repositories that don't override single-project fetch.
extension ProjectRepository {
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        let all = try await fetchProjects()
        return all.first { $0.id == id }
    }
}

/// Sample project data provider delivering structured preview assembly projects.
struct SampleProjectRepository: ProjectRepository {
    
    func fetchProjects() async throws -> [AssemblyProject] {
        return SampleProjectData.sampleProjects
    }
    
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        return SampleProjectData.sampleActivity
    }
}

/// Backwards-compatible alias for unit test suites and existing callers
typealias MockProjectRepository = SampleProjectRepository

/// Dedicated preview dataset fixture container exclusively for SwiftUI Canvas previews.
enum PreviewProjectFixture {
    /// In-memory sample projects: all production projects are loaded via database or bundled JSON.
    static let sampleProjects: [AssemblyProject] = []
    
    /// Sample activity history: real session records are loaded from SwiftData/database.
    static let sampleActivity: [ActivityItemModel] = []
    
    #if DEBUG
    /// Isolated fixture model exclusively for SwiftUI Canvas previews (never loaded by app runtime).
    static let previewProject = AssemblyProject(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        title: "LED Circuit",
        subtitle: "Basic breadboard circuit with resistor & LED",
        category: "Electronics",
        difficulty: .beginner,
        estimatedMinutes: 15,
        totalSteps: 4,
        completedSteps: 1,
        imageName: "bolt.batteryblock.fill",
        isActive: true,
        nextAction: "Connect the signal wire to pin R1",
        description: "Build a simple LED circuit using a breadboard.",
        components: [
            ComponentRequirement(name: "Breadboard", detail: "830 tie-point board", isRequired: true)
        ],
        steps: [
            ProjectStepSummary(stepOrder: 1, title: "Attach Resistor to Header", instruction: "Insert leads into header.", isCompleted: true),
            ProjectStepSummary(stepOrder: 2, title: "Connect Anode Lead", instruction: "Align long lead with pin.", isCompleted: false)
        ]
    )
    #endif
}

typealias SampleProjectData = PreviewProjectFixture

#if DEBUG
/// Backwards-compatible alias for unit test suites and preview helpers
typealias MockProjectData = PreviewProjectFixture
#endif


