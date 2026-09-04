//
//  CloudKitSyncService.swift
//  AssembleAI
//

import Foundation
import CloudKit


/// CloudKit implementation of the cloud synchronization backend.
final class CloudKitSyncService: CloudSyncBackend, @unchecked Sendable {
    
    private let container: CKContainer
    private let database: CKDatabase
    
    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - CloudSyncBackend
    
    func uploadSessions(_ sessions: [AssemblySession]) async throws -> [AssemblySession] {
        var uploaded: [AssemblySession] = []
        
        for session in sessions {
            let recordID = CKRecord.ID(recordName: session.id.uuidString)
            let record = CKRecord(recordType: "AssemblySession", recordID: recordID)
            
            record["projectId"] = session.projectId.uuidString as CKRecordValue
            record["status"] = session.status.rawValue as CKRecordValue
            record["currentStepIndex"] = session.currentStepIndex as CKRecordValue
            record["currentStepOrder"] = session.currentStepOrder as CKRecordValue
            record["attempts"] = session.attempts as CKRecordValue
            record["errors"] = session.errors as CKRecordValue
            record["startedAt"] = session.startedAt as CKRecordValue
            if let ended = session.endedAt {
                record["endedAt"] = ended as CKRecordValue
            }
            record["updatedAt"] = Date() as CKRecordValue
            
            do {
                _ = try await database.save(record)
                var updated = session
                updated.syncState = .synced
                updated.updatedAt = Date()
                uploaded.append(updated)
            } catch {
                // If single record fails, continue with remainder
                continue
            }
        }
        
        return uploaded
    }
    
    func fetchRemoteSessions(since: Date?) async throws -> [AssemblySession] {
        // Query records modified since timestamp
        let predicate: NSPredicate
        if let sinceDate = since {
            predicate = NSPredicate(format: "modificationDate > %@", sinceDate as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        
        let query = CKQuery(recordType: "AssemblySession", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        var fetched: [AssemblySession] = []
        
        do {
            let (matchResults, _) = try await database.records(matching: query)
            for (_, recordResult) in matchResults {
                if case .success(let record) = recordResult,
                   let id = UUID(uuidString: record.recordID.recordName),
                   let projectStr = record["projectId"] as? String,
                   let projectId = UUID(uuidString: projectStr),
                   let statusStr = record["status"] as? String,
                   let status = SessionStatus(rawValue: statusStr) {
                    
                    let stepIndex = record["currentStepIndex"] as? Int ?? 0
                    let stepOrder = record["currentStepOrder"] as? Int ?? 1
                    let attempts = record["attempts"] as? Int ?? 0
                    let errors = record["errors"] as? Int ?? 0
                    let startedAt = record["startedAt"] as? Date ?? Date()
                    let endedAt = record["endedAt"] as? Date
                    let updatedAt = record["updatedAt"] as? Date ?? Date()
                    
                    fetched.append(
                        AssemblySession(
                            id: id,
                            projectId: projectId,
                            currentStepIndex: stepIndex,
                            attempts: attempts,
                            errors: errors,
                            startedAt: startedAt,
                            endedAt: endedAt,
                            status: status,
                            currentStepOrder: stepOrder,
                            updatedAt: updatedAt,
                            syncState: .synced
                        )
                    )
                }
            }
        } catch {
            return []
        }
        
        return fetched
    }
    
    func deleteRemoteSession(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await database.deleteRecord(withID: recordID)
    }
}
