//
//  LocalUser.swift
//  AssembleAI
//

import Foundation
import SwiftData

@Model
final class LocalUser {
    @Attribute(.unique) var id: String
    var name: String?
    var email: String?
    var avatarUrl: String?
    var providerRaw: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        name: String?,
        email: String?,
        avatarUrl: String? = nil,
        providerRaw: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.providerRaw = providerRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDomainModel() -> User {
        User(
            id: id,
            name: name,
            email: email,
            avatarUrl: avatarUrl,
            provider: AuthProvider(rawValue: providerRaw) ?? .guest,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func fromDomainModel(_ user: User) -> LocalUser {
        LocalUser(
            id: user.id,
            name: user.name,
            email: user.email,
            avatarUrl: user.avatarUrl,
            providerRaw: user.provider.rawValue,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
    }
}
