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
    var avatarSymbol: String
    var avatarColorHex: String
    var bio: String
    var experienceLevel: String
    var providerRaw: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        name: String?,
        email: String?,
        avatarUrl: String? = nil,
        avatarSymbol: String = "person.crop.circle.fill",
        avatarColorHex: String = "#0A84FF",
        bio: String = "",
        experienceLevel: String = "Beginner",
        providerRaw: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.avatarSymbol = avatarSymbol
        self.avatarColorHex = avatarColorHex
        self.bio = bio
        self.experienceLevel = experienceLevel
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
            avatarSymbol: avatarSymbol,
            avatarColorHex: avatarColorHex,
            bio: bio,
            experienceLevel: experienceLevel,
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
            avatarSymbol: user.avatarSymbol,
            avatarColorHex: user.avatarColorHex,
            bio: user.bio,
            experienceLevel: user.experienceLevel,
            providerRaw: user.provider.rawValue,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
    }
}
