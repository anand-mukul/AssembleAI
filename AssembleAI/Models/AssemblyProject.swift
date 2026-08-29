//
//  AssemblyProject.swift
//  AssembleAI
//

import Foundation
import SwiftUI

/// Assembly project difficulty level.
enum Difficulty: String, CaseIterable, Codable, Hashable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var color: Color {
        switch self {
        case .beginner: return AppColors.success
        case .intermediate: return AppColors.warning
        case .advanced: return AppColors.brandPrimary
        }
    }
}

/// Component requirement specification for an assembly task.
struct ComponentRequirement: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let detail: String
    let isRequired: Bool
    
    init(id: UUID = UUID(), name: String, detail: String, isRequired: Bool = true) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isRequired = isRequired
    }
}

/// Physical step summary for an assembly project.
struct ProjectStepSummary: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let stepOrder: Int
    let title: String
    let instruction: String
    let isCompleted: Bool
    
    init(id: UUID = UUID(), stepOrder: Int, title: String, instruction: String, isCompleted: Bool = false) {
        self.id = id
        self.stepOrder = stepOrder
        self.title = title
        self.instruction = instruction
        self.isCompleted = isCompleted
    }
}

/// Domain model for an electronics or physical assembly project.
struct AssemblyProject: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let category: String
    let difficulty: Difficulty
    let estimatedMinutes: Int
    let totalSteps: Int
    let completedSteps: Int
    let imageName: String?
    let isActive: Bool
    let nextAction: String?
    let description: String
    let components: [ComponentRequirement]
    let steps: [ProjectStepSummary]
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        category: String,
        difficulty: Difficulty,
        estimatedMinutes: Int,
        totalSteps: Int,
        completedSteps: Int,
        imageName: String? = nil,
        isActive: Bool = false,
        nextAction: String? = nil,
        description: String = "",
        components: [ComponentRequirement] = [],
        steps: [ProjectStepSummary] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.imageName = imageName
        self.isActive = isActive
        self.nextAction = nextAction
        self.description = description
        self.components = components
        self.steps = steps
    }
    
    // MARK: - Computed Properties
    
    /// Normalized progress ratio [0.0 ... 1.0]
    var progress: Double {
        guard totalSteps > 0 else { return 0.0 }
        return min(1.0, Double(completedSteps) / Double(totalSteps))
    }
    
    /// Formatted progress percentage text
    var progressText: String {
        "\(Int(progress * 100))%"
    }
    
    /// Number of remaining steps
    var remainingSteps: Int {
        max(0, totalSteps - completedSteps)
    }
    
    /// Whether all steps have been completed
    var isCompleted: Bool {
        completedSteps >= totalSteps
    }
    
    /// VoiceOver descriptive summary
    var accessibilityLabelSummary: String {
        "\(title), \(category), \(difficulty.rawValue) level, \(completedSteps) of \(totalSteps) steps completed, \(progressText)"
    }
}

/// Recent activity item entry for completed steps.
struct ActivityItemModel: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let stepOrder: Int
    let projectTitle: String
    let timestampDescription: String
    let iconName: String
    
    init(
        id: UUID = UUID(),
        stepOrder: Int,
        projectTitle: String,
        timestampDescription: String,
        iconName: String = "checkmark.circle.fill"
    ) {
        self.id = id
        self.stepOrder = stepOrder
        self.projectTitle = projectTitle
        self.timestampDescription = timestampDescription
        self.iconName = iconName
    }
}
