//
//  AppEnvironment.swift
//  AssembleAI
//

import Foundation

/// Application execution environment mode.
public enum AppEnvironment: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case demo = "Demo Mode"
    case development = "Development"
    case production = "Production"
}

/// Interaction evaluation mode for comparative research experiments.
public enum InteractionMode: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case liveTutor = "liveTutor"
    case manual = "manual"
    case guided = "guided"
    case baseline = "baseline"
}

/// Reproducible deterministic demo scenario selector for presentations and evaluation.
public enum DemoScenario: String, CaseIterable, Identifiable, Codable, Hashable, Equatable, Sendable {
    case correctPlacement = "Correct Placement"
    case wrongPosition = "Wrong Position (Step 2)"
    case missingComponent = "Missing Component"
    case wrongConnection = "Wrong Connection (Step 4)"
    case uncertainImage = "Uncertain Image (Step 3)"
    case completeAssembly = "Full Assembly Script"
    
    public var id: String { rawValue }
}
