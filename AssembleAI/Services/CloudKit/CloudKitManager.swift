//
//  CloudKitManager.swift
//  AssembleAI
//

import Foundation
import CloudKit
import Combine

/// Centralized manager for Apple CloudKit container initialization and iCloud account status inspection.
@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var userRecordID: CKRecord.ID? = nil
    @Published var error: String? = nil
    
    let container: CKContainer
    let privateDatabase: CKDatabase
    
    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier, !identifier.isEmpty {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
        self.privateDatabase = container.privateCloudDatabase
        
        Task {
            await checkAccountStatus()
        }
    }
    
    /// Queries the user's current iCloud account availability status.
    func checkAccountStatus() async {
        guard AppConfig.isCloudKitEnabled else {
            accountStatus = .couldNotDetermine
            isAvailable = false
            userRecordID = nil
            error = "CloudKit is disabled for this build."
            return
        }
        
        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            self.isAvailable = (status == .available)
            
            if status == .available {
                let recordID = try await container.userRecordID()
                self.userRecordID = recordID
            } else {
                self.userRecordID = nil
            }
        } catch {
            self.accountStatus = .couldNotDetermine
            self.isAvailable = false
            self.error = error.localizedDescription
        }
    }
}
