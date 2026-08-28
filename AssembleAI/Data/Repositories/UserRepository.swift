//
//  UserRepository.swift
//  AssembleAI
//

import Foundation
import SwiftData

protocol UserRepository: Sendable {
    func fetchCurrentUser() async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteCurrentUser() async throws
}

final class UserRepositoryImpl: UserRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func fetchCurrentUser() async throws -> User? {
        let descriptor = FetchDescriptor<LocalUser>()
        let users = try modelContext.fetch(descriptor)
        return users.first?.toDomainModel()
    }
    
    @MainActor
    func saveUser(_ user: User) async throws {
        let descriptor = FetchDescriptor<LocalUser>()
        let existingUsers = try modelContext.fetch(descriptor)
        
        for existing in existingUsers {
            modelContext.delete(existing)
        }
        
        let localUser = LocalUser.fromDomainModel(user)
        modelContext.insert(localUser)
        try modelContext.save()
    }
    
    @MainActor
    func deleteCurrentUser() async throws {
        let descriptor = FetchDescriptor<LocalUser>()
        let users = try modelContext.fetch(descriptor)
        for user in users {
            modelContext.delete(user)
        }
        try modelContext.save()
    }
}
