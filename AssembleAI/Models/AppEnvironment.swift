//
//  AppEnvironment.swift
//  AssembleAI
//

import Foundation

/// Application execution environment mode.
nonisolated enum AppEnvironment: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case development = "Development"
    case production = "Production"
}

/// Interaction evaluation mode for comparative research experiments.
nonisolated enum InteractionMode: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case liveTutor = "liveTutor"
    case manual = "manual"
    case guided = "guided"
    case baseline = "baseline"
}

