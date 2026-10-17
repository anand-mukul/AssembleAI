//
//  ProfileDTO.swift
//  AssembleAI
//
//  Network Data Transfer Object mapping directly to Supabase PostgREST `public.profiles`.
//

import Foundation

/// PostgREST DTO representation of `public.profiles`.
struct ProfileDTO: Codable, Sendable {
    let id: String
    var fullName: String?
    var email: String?
    var avatarUrl: String?
    var avatarSymbol: String?
    var avatarColorHex: String?
    var bio: String?
    var experienceLevel: String?
    var totalAssemblyMinutes: Int?
    var completedSessionsCount: Int?
    var isAdmin: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case avatarUrl = "avatar_url"
        case avatarSymbol = "avatar_symbol"
        case avatarColorHex = "avatar_color_hex"
        case bio
        case experienceLevel = "experience_level"
        case totalAssemblyMinutes = "total_assembly_minutes"
        case completedSessionsCount = "completed_sessions_count"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String,
        fullName: String? = nil,
        email: String? = nil,
        avatarUrl: String? = nil,
        avatarSymbol: String? = "person.crop.circle.fill",
        avatarColorHex: String? = "#0A84FF",
        bio: String? = "",
        experienceLevel: String? = "Beginner",
        totalAssemblyMinutes: Int? = 0,
        completedSessionsCount: Int? = 0,
        isAdmin: Bool? = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.avatarUrl = avatarUrl
        self.avatarSymbol = avatarSymbol
        self.avatarColorHex = avatarColorHex
        self.bio = bio
        self.experienceLevel = experienceLevel
        self.totalAssemblyMinutes = totalAssemblyMinutes
        self.completedSessionsCount = completedSessionsCount
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toDomain(provider: AuthProvider = .email) -> User {
        User(
            id: id,
            name: fullName,
            email: email,
            avatarUrl: avatarUrl,
            avatarSymbol: avatarSymbol ?? "person.crop.circle.fill",
            avatarColorHex: avatarColorHex ?? "#0A84FF",
            bio: bio ?? "",
            experienceLevel: experienceLevel ?? "Beginner",
            provider: provider,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
