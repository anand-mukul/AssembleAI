//
//  SupabaseProjectRepository.swift
//  AssembleAI
//

import Foundation

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
        guard AppConfig.isSupabaseConfigured else {
            return try await fallbackRepository.fetchProjects()
        }
        do {
            let remote = try await supabaseService.fetchFullAssemblyProjects()
            if !remote.isEmpty {
                return remote
            }
        } catch {
            // Supabase unreachable or offline: fall through to bundled package loader
        }
        return try await fallbackRepository.fetchProjects()
    }
    
    func fetchProject(byId id: UUID) async throws -> AssemblyProject? {
        guard AppConfig.isSupabaseConfigured else {
            return try await fallbackRepository.fetchProject(byId: id)
        }
        do {
            let remote = try await supabaseService.fetchFullAssemblyProjects()
            if let match = remote.first(where: { $0.id == id }) {
                return match
            }
        } catch {
            // Offline fallback
        }
        return try await fallbackRepository.fetchProject(byId: id)
    }
    
    func fetchRecentActivity() async throws -> [ActivityItemModel] {
        try await fallbackRepository.fetchRecentActivity()
    }
}
