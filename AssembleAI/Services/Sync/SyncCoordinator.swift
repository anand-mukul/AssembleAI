//
//  SyncCoordinator.swift
//  AssembleAI
//

import Foundation
import SwiftData
import Combine

/// Synchronizes pending local SwiftData changes with Apple CloudKit when iCloud is active.
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncedAt: Date? = nil
    
    private let modelContext: ModelContext
    private let cloudKitManager: CloudKitManager
    private let cloudKitService: CloudKitProjectService
    
    init(
        modelContext: ModelContext,
        cloudKitManager: CloudKitManager? = nil,
        cloudKitService: CloudKitProjectService? = nil
    ) {
        let manager = cloudKitManager ?? CloudKitManager.shared
        self.modelContext = modelContext
        self.cloudKitManager = manager
        self.cloudKitService = cloudKitService ?? CloudKitProjectService(cloudKitManager: manager)
    }
    
    /// Synchronizes all pending local SwiftData modifications to CloudKit.
    func synchronizePendingChanges() async {
        await cloudKitManager.checkAccountStatus()
        guard cloudKitManager.isAvailable else { return }
        
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
                try await cloudKitService.saveProject(domainProject)
                localProject.syncStateRaw = SyncState.synced.rawValue
            }
            
            try modelContext.save()
        } catch {
            // Retain pending status for retry on next sync cycle
        }
    }
}
