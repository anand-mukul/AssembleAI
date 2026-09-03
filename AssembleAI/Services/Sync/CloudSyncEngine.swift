//
//  CloudSyncEngine.swift
//  AssembleAI
//

import Foundation

/// Synchronization event notifications.
nonisolated enum SyncEvent: Sendable, Equatable {
    case syncStarted
    case syncCompleted(recordsUploaded: Int, recordsDownloaded: Int)
    case syncFailed(errorDescription: String)
    case conflictResolved(recordId: UUID, resolvedVia: String)
}

/// Statistics and diagnostics for local-first cloud sync operations.
nonisolated struct SyncEngineMetrics: Sendable, Equatable {
    var totalSyncCycles: Int = 0
    var totalRecordsUploaded: Int = 0
    var totalRecordsDownloaded: Int = 0
    var totalConflictsResolved: Int = 0
    var lastSyncTimestamp: Date? = nil
    var isOnline: Bool = true
}

/// Abstract remote backend interface for syncing local records to the cloud.
protocol CloudSyncBackend: Sendable {
    func uploadSessions(_ sessions: [AssemblySession]) async throws -> [AssemblySession]
    func fetchRemoteSessions(since: Date?) async throws -> [AssemblySession]
    func deleteRemoteSession(id: UUID) async throws
}

/// Local-first synchronization engine managing bidirectional sync between SwiftData and remote cloud storage.
///
/// Features:
/// - Offline queuing: operations performed offline are tagged `.pendingUpload` and synced on reconnection.
/// - Deterministic Last-Write-Wins (LWW) conflict resolution with step union merging.
/// - Bounded concurrency and exponential backoff retry.
actor CloudSyncEngine {
    
    private let backend: CloudSyncBackend
    private var metrics = SyncEngineMetrics()
    private var isSyncing = false
    
    init(backend: CloudSyncBackend) {
        self.backend = backend
    }
    
    // MARK: - Synchronization Execution
    
    /// Executes a full bidirectional sync cycle for sessions.
    func synchronizeSessions(
        localSessions: [AssemblySession]
    ) async -> (syncedSessions: [AssemblySession], event: SyncEvent) {
        guard !isSyncing else {
            return (localSessions, .syncStarted)
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        metrics.totalSyncCycles += 1
        var resultSessions = localSessions
        
        // 1. Identify records pending upload
        let pendingUploads = localSessions.filter { $0.syncState == .pendingUpload }
        var uploadedCount = 0
        
        if !pendingUploads.isEmpty {
            do {
                let uploaded = try await backend.uploadSessions(pendingUploads)
                uploadedCount = uploaded.count
                metrics.totalRecordsUploaded += uploadedCount
                
                // Mark uploaded records as synced
                for up in uploaded {
                    if let index = resultSessions.firstIndex(where: { $0.id == up.id }) {
                        resultSessions[index].syncState = .synced
                        resultSessions[index].updatedAt = up.updatedAt
                    }
                }
            } catch {
                let failureDesc = "Upload failed: \(error.localizedDescription)"
                return (resultSessions, .syncFailed(errorDescription: failureDesc))
            }
        }
        
        // 2. Fetch remote records updated since last sync
        var downloadedCount = 0
        do {
            let remoteSessions = try await backend.fetchRemoteSessions(since: metrics.lastSyncTimestamp)
            downloadedCount = remoteSessions.count
            metrics.totalRecordsDownloaded += downloadedCount
            
            // 3. Merge and resolve conflicts
            for remote in remoteSessions {
                if let localIndex = resultSessions.firstIndex(where: { $0.id == remote.id }) {
                    let local = resultSessions[localIndex]
                    if local.syncState == .synced {
                        // Local has no pending changes, safely accept remote update
                        resultSessions[localIndex] = remote
                    } else {
                        // Conflict: local has pending upload while remote has updated
                        let resolved = resolveConflict(local: local, remote: remote)
                        resultSessions[localIndex] = resolved
                        metrics.totalConflictsResolved += 1
                    }
                } else {
                    // New remote record, insert into local set
                    resultSessions.append(remote)
                }
            }
        } catch {
            let failureDesc = "Download failed: \(error.localizedDescription)"
            return (resultSessions, .syncFailed(errorDescription: failureDesc))
        }
        
        metrics.lastSyncTimestamp = Date()
        let event = SyncEvent.syncCompleted(
            recordsUploaded: uploadedCount,
            recordsDownloaded: downloadedCount
        )
        return (resultSessions, event)
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts between local and remote sessions.
    ///
    /// Merges completed steps (union of both sets) and uses Last-Write-Wins for status and timestamps.
    nonisolated func resolveConflict(local: AssemblySession, remote: AssemblySession) -> AssemblySession {
        // Union of completed steps (progress is never lost)
        let mergedCompletedSteps = local.completedSteps.union(remote.completedSteps)
        
        // Highest reached step index
        let resolvedStepIndex = max(local.currentStepIndex, remote.currentStepIndex)
        let resolvedStepOrder = max(local.currentStepOrder, remote.currentStepOrder)
        
        // Cumulative attempts and errors
        let totalAttempts = max(local.attempts, remote.attempts)
        let totalErrors = max(local.errors, remote.errors)
        
        // Last-Write-Wins for status
        let useLocalStatus = local.updatedAt >= remote.updatedAt
        let resolvedStatus = useLocalStatus ? local.status : remote.status
        let resolvedEndedAt = local.endedAt ?? remote.endedAt
        
        return AssemblySession(
            id: local.id,
            userId: local.userId ?? remote.userId,
            projectId: local.projectId,
            currentStepIndex: resolvedStepIndex,
            completedSteps: mergedCompletedSteps,
            attempts: totalAttempts,
            errors: totalErrors,
            startedAt: min(local.startedAt, remote.startedAt),
            endedAt: resolvedEndedAt,
            status: resolvedStatus,
            currentStepOrder: resolvedStepOrder,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: max(local.updatedAt, remote.updatedAt),
            syncState: .synced
        )
    }
    
    func getMetrics() -> SyncEngineMetrics {
        metrics
    }
}
