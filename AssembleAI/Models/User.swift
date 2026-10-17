//
//  User.swift
//  AssembleAI
//

import Foundation

/// Represents the authentication provider used by the user.
nonisolated enum AuthProvider: String, Codable, Hashable, Equatable, Sendable {
    case apple
    case email
    case guest
}

/// Represents an authenticated or guest user session in AssembleAI.
nonisolated struct User: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: String
    var name: String?
    var email: String?
    var avatarUrl: String?
    var avatarSymbol: String
    var avatarColorHex: String
    var bio: String
    var experienceLevel: String
    let provider: AuthProvider
    let createdAt: Date
    var updatedAt: Date
    
    nonisolated init(
        id: String,
        name: String?,
        email: String?,
        avatarUrl: String? = nil,
        avatarSymbol: String = "person.crop.circle.fill",
        avatarColorHex: String = "#0A84FF",
        bio: String = "",
        experienceLevel: String = "Beginner",
        provider: AuthProvider,
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
        self.provider = provider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isGuest: Bool {
        return provider == .guest
    }
    
    var isAnonymous: Bool {
        return isGuest
    }
    
    var fullName: String? {
        return name
    }
    
    var displayName: String {
        if let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        if isGuest {
            return "Guest User"
        }
        if let email = email {
            return email.components(separatedBy: "@").first ?? "User"
        }
        return "AssembleAI User"
    }
}
