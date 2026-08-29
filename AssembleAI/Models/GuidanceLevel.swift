//
//  GuidanceLevel.swift
//  AssembleAI
//

import Foundation

/// User preference for guidance detail level.
nonisolated enum GuidanceLevel: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case concise = "Concise"
    case detailed = "Detailed"
}
