//
//  ProjectRepositoryFactory.swift
//  AssembleAI
//

import Foundation
import SwiftData

/// Resolves the appropriate `ProjectRepository` implementation based on the current environment.
///
/// Resolution strategy:
/// - **Production & Development**: `BundledProjectRepository` loading from JSON packages.
///   Falls back to `MockProjectRepository` if no bundled JSON files are found.
/// - **Testing**: Callers inject `MockProjectRepository` directly via initializer.
enum ProjectRepositoryFactory {
    
    /// Resolves the production-appropriate project repository connected to SwiftData and Supabase.
    @MainActor
    static func resolve() -> ProjectRepository {
        let context = PersistenceController.shared.container.mainContext
        let supabase = SupabaseProjectService(supabaseManager: SupabaseManager.shared)
        return LocalFirstProjectRepository(modelContext: context, supabaseService: supabase)
    }
    
    /// Returns a sample repository for preview/test injection.
    static func mock() -> ProjectRepository {
        SampleProjectRepository()
    }
    
    /// Returns a bundled repository with a custom directory.
    static func bundled(directory: String = "Projects") -> ProjectRepository {
        BundledProjectRepository(bundleDirectory: directory)
    }
    
    /// Returns a local SwiftData-first repository with optional Supabase backend sync.
    @MainActor
    static func localFirst(
        modelContext: ModelContext? = nil,
        supabaseService: SupabaseProjectService? = nil
    ) -> LocalFirstProjectRepository {
        let context = modelContext ?? PersistenceController.shared.container.mainContext
        return LocalFirstProjectRepository(modelContext: context, supabaseService: supabaseService)
    }
}
