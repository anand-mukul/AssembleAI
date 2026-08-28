//
//  CloudKitProjectService.swift
//  AssembleAI
//

import Foundation
import CloudKit

/// Service interacting with CloudKit Private Database for `Project`, `AssemblyStep`, `Component`, and `CKAsset` records.
actor CloudKitProjectService {
    private let cloudKitManager: CloudKitManager
    
    init(cloudKitManager: CloudKitManager = .shared) {
        self.cloudKitManager = cloudKitManager
    }
    
    /// Record Type Identifier Constants
    enum RecordType {
        static let project = "Project"
        static let assemblyStep = "AssemblyStep"
        static let component = "Component"
        static let assemblySession = "AssemblySession"
        static let attempt = "Attempt"
    }
    
    /// Fetches all Projects stored in the user's private CloudKit database.
    func fetchProjects() async throws -> [Project] {
        guard cloudKitManager.isAvailable else { return [] }
        
        let query = CKQuery(recordType: RecordType.project, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        let (matchResults, _) = try await cloudKitManager.privateDatabase.records(matching: query)
        var projects: [Project] = []
        
        for (_, result) in matchResults {
            if case .success(let record) = result, let project = projectFromRecord(record) {
                projects.append(project)
            }
        }
        
        return projects
    }
    
    /// Saves or updates a Project record in CloudKit.
    func saveProject(_ project: Project) async throws {
        guard cloudKitManager.isAvailable else { return }
        
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        let record: CKRecord
        
        do {
            record = try await cloudKitManager.privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: RecordType.project, recordID: recordID)
        }
        
        record["ownerId"] = project.ownerId.uuidString
        record["title"] = project.title
        record["description"] = project.description
        record["difficulty"] = project.difficulty
        record["estimatedMinutes"] = project.estimatedMinutes
        record["updatedAt"] = project.updatedAt
        record["createdAt"] = project.createdAt
        
        try await cloudKitManager.privateDatabase.save(record)
    }
    
    /// Deletes a Project record from CloudKit.
    func deleteProject(id: UUID) async throws {
        guard cloudKitManager.isAvailable else { return }
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await cloudKitManager.privateDatabase.deleteRecord(withID: recordID)
    }
    
    // MARK: - Helper Mapping Methods
    
    private func projectFromRecord(_ record: CKRecord) -> Project? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let ownerIdString = record["ownerId"] as? String,
              let ownerId = UUID(uuidString: ownerIdString),
              let title = record["title"] as? String else {
            return nil
        }
        
        let description = record["description"] as? String ?? ""
        let difficulty = record["difficulty"] as? String ?? "Beginner"
        let estimatedMinutes = record["estimatedMinutes"] as? Int ?? 30
        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? Date()
        
        return Project(
            id: id,
            ownerId: ownerId,
            title: title,
            description: description,
            difficulty: difficulty,
            estimatedMinutes: estimatedMinutes,
            thumbnailPath: nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: .synced
        )
    }
}
