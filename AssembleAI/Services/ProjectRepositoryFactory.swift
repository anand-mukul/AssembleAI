//
//  ProjectRepositoryFactory.swift
//  AssembleAI
//

import Foundation

/// Resolves the appropriate `ProjectRepository` implementation based on the current environment.
///
/// Resolution strategy:
/// - **Production & Development**: `SupabaseProjectRepository` loading live from Supabase PostgreSQL,
///   with seamless fallback to `BundledProjectRepository` if offline or unreachable.
/// - **Testing & Previews**: Callers inject `SampleProjectRepository` directly via initializer.
enum ProjectRepositoryFactory {
    
    /// Resolves the production-appropriate project repository connected to Supabase with bundled fallback.
    @MainActor
    static func resolve() -> ProjectRepository {
        guard AppConfig.isSupabaseConfigured else {
            return BundledProjectRepository()
        }
        let supabase = SupabaseProjectService(supabaseManager: SupabaseManager.shared)
        return SupabaseProjectRepository(supabaseService: supabase)
    }
    
    /// Returns a local-first project repository (alias to resolve for testing and backward compatibility).
    @MainActor
    static func localFirst() -> ProjectRepository {
        resolve()
    }
    
    #if DEBUG
    /// Returns a sample repository for preview/test injection.
    static func mock() -> ProjectRepository {
        SampleProjectRepository()
    }
    #endif
    
    /// Returns a bundled repository with a custom directory.
    static func bundled(directory: String = "Projects") -> ProjectRepository {
        BundledProjectRepository(bundleDirectory: directory)
    }
    
    /// Returns a remote database repository querying Supabase.
    @MainActor
    static func remote(
        supabaseService: SupabaseProjectService? = nil
    ) -> ProjectRepository {
        let service = supabaseService ?? SupabaseProjectService(supabaseManager: SupabaseManager.shared)
        return SupabaseProjectRepository(supabaseService: service)
    }
}
