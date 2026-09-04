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
    
    /// Resolves the production-appropriate project repository.
    ///
    /// If bundled JSON project files exist in the `Projects` resource directory,
    /// returns a `BundledProjectRepository`. Otherwise, falls back to `MockProjectRepository`
    /// to ensure the app always has content to display.
    static func resolve() -> ProjectRepository {
        let bundledProjects = ProjectPackageLoader.loadAllFromBundle()
        if !bundledProjects.isEmpty {
            return BundledProjectRepository()
        } else {
            // Fallback to sample data when running in environments where bundle resources are not present (e.g., Xcode Previews)
            return SampleProjectRepository()
        }
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
