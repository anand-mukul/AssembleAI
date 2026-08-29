//
//  User.swift
//  AssembleAI
//

import Foundation

/// Represents the authentication provider used by the user.
enum AuthProvider: String, Codable, Hashable, Equatable, Sendable {
    case apple
    case email
    case guest
}

/// Represents an authenticated or guest user session in AssembleAI.
nonisolated struct User: Identifiable, Hashable, Codable, Equatable, Sendable {
    let id: String
    let name: String?
    let email: String?
    let avatarUrl: String?
    let provider: AuthProvider
    let createdAt: Date
    let updatedAt: Date
    
    nonisolated init(
        id: String,
        name: String?,
        email: String?,
        avatarUrl: String? = nil,
        provider: AuthProvider,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
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
        if isGuest {
            return "Guest User"
        }
        if let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        if let email = email {
            return email.components(separatedBy: "@").first ?? "User"
        }
        return "AssembleAI User"
    }
}
