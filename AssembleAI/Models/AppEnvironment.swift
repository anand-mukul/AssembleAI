//
//  AppEnvironment.swift
//  AssembleAI
//

import Foundation

/// Application execution environment mode.
enum AppEnvironment: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case demo = "Demo Mode"
    case development = "Development"
    case production = "Production"
}

/// Interaction evaluation mode for comparative research experiments.
enum InteractionMode: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case guided = "Guided (AssembleAI)"
    case baseline = "Baseline (Static Text)"
}

/// Reproducible deterministic demo scenario selector for presentations and evaluation.
enum DemoScenario: String, CaseIterable, Identifiable, Codable, Hashable, Equatable, Sendable {
    case correctPlacement = "Correct Placement"
    case wrongPosition = "Wrong Position (Step 2)"
    case missingComponent = "Missing Component"
    case wrongConnection = "Wrong Connection (Step 4)"
    case uncertainImage = "Uncertain Image (Step 3)"
    case completeAssembly = "Full Assembly Script"
    
    var id: String { rawValue }
}
