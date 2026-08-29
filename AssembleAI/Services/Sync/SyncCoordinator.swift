//
//  SyncCoordinator.swift
//  AssembleAI
//

import Foundation
import SwiftData
import Combine

/// Synchronizes pending local SwiftData changes with Supabase backend when online.
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncedAt: Date? = nil
    
    private let modelContext: ModelContext
    private let supabaseManager: SupabaseManager
    private let supabaseService: SupabaseProjectService
    
    init(
        modelContext: ModelContext,
        supabaseManager: SupabaseManager = .shared,
        supabaseService: SupabaseProjectService = SupabaseProjectService()
    ) {
        self.modelContext = modelContext
        self.supabaseManager = supabaseManager
        self.supabaseService = supabaseService
    }
    
    /// Synchronizes all pending local SwiftData modifications to Supabase.
    func synchronizePendingChanges() async {
        guard supabaseManager.isConnected else { return }
        
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncedAt = Date()
        }
        
        do {
            let fetchPendingProjects = FetchDescriptor<LocalProject>(
                predicate: #Predicate<LocalProject> { $0.syncStateRaw == "pendingUpload" }
            )
            let pendingProjects = try modelContext.fetch(fetchPendingProjects)
            
            for localProject in pendingProjects {
                let domainProject = localProject.toDomainModel()
                try await supabaseService.saveProject(domainProject)
                localProject.syncStateRaw = SyncState.synced.rawValue
            }
            
            try modelContext.save()
        } catch {
            // Retain pending status for retry on next sync cycle
        }
    }
}
