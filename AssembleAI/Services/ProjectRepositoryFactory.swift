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
        let hasBundledProjects = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: "Projects"
        )?.isEmpty == false
        
        if hasBundledProjects {
            return BundledProjectRepository()
        } else {
            // Fallback to mock data when no JSON packages are bundled.
            // This ensures the app runs correctly during development and in
            // Xcode Previews where bundle resources may not be available.
            return MockProjectRepository()
        }
    }
    
    /// Returns a mock repository for test injection.
    static func mock() -> ProjectRepository {
        MockProjectRepository()
    }
    
    /// Returns a bundled repository with a custom directory.
    static func bundled(directory: String = "Projects") -> ProjectRepository {
        BundledProjectRepository(bundleDirectory: directory)
    }
    
    /// Returns a local SwiftData-first repository with optional Supabase backend sync.
    @MainActor
    static func localFirst(
        modelContext: ModelContext = PersistenceController.shared.container.mainContext,
        supabaseService: SupabaseProjectService? = nil
    ) -> LocalFirstProjectRepository {
        LocalFirstProjectRepository(modelContext: modelContext, supabaseService: supabaseService)
    }
}
