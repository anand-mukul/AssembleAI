//
//  AssemblyProject.swift
//  AssembleAI
//

import Foundation
import SwiftUI

/// Assembly project difficulty level.
nonisolated enum Difficulty: String, CaseIterable, Codable, Hashable, Sendable {
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
nonisolated struct ComponentRequirement: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let detail: String
    let isRequired: Bool
    
    /// Unique part identifier for BOM cross-referencing (e.g., "part_res_220").
    let partId: String?
    
    /// Typed component classification for Core ML model class mapping.
    let componentType: ComponentType?
    
    /// Physical attributes enabling on-device visual identification.
    let physicalAttributes: ComponentPhysicalAttributes?
    
    /// Quantity of this component required for the project.
    let quantity: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        isRequired: Bool = true,
        partId: String? = nil,
        componentType: ComponentType? = nil,
        physicalAttributes: ComponentPhysicalAttributes? = nil,
        quantity: Int = 1
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isRequired = isRequired
        self.partId = partId
        self.componentType = componentType
        self.physicalAttributes = physicalAttributes
        self.quantity = quantity
    }
}

/// Physical step summary for an assembly project.
nonisolated struct ProjectStepSummary: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let stepOrder: Int
    let title: String
    let instruction: String
    let isCompleted: Bool
    let expectedDurationMinutes: Int
    
    /// Machine-verifiable visual contract defining the target physical state for this step.
    let visualContract: VisualContract?
    
    /// Documented common mistakes with detection conditions and corrective guidance.
    let commonMistakes: [CommonMistake]
    
    init(
        id: UUID = UUID(),
        stepOrder: Int,
        title: String,
        instruction: String,
        isCompleted: Bool = false,
        expectedDurationMinutes: Int = 0,
        visualContract: VisualContract? = nil,
        commonMistakes: [CommonMistake] = []
    ) {
        self.id = id
        self.stepOrder = stepOrder
        self.title = title
        self.instruction = instruction
        self.isCompleted = isCompleted
        self.expectedDurationMinutes = expectedDurationMinutes
        self.visualContract = visualContract
        self.commonMistakes = commonMistakes
    }
}

typealias StepSummary = ProjectStepSummary

/// Domain model for an electronics or physical assembly project.
nonisolated struct AssemblyProject: Identifiable, Hashable, Codable, Sendable {
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
    
    /// Schema version for forward-compatible package evolution.
    let schemaVersion: String
    
    /// Assembly domain (electronics, physical, or hybrid).
    let domain: AssemblyDomain
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        category: String,
        difficulty: Difficulty,
        estimatedMinutes: Int,
        totalSteps: Int,
        completedSteps: Int = 0,
        imageName: String? = nil,
        isActive: Bool = false,
        nextAction: String? = nil,
        description: String = "",
        components: [ComponentRequirement] = [],
        steps: [ProjectStepSummary] = [],
        schemaVersion: String = "1.0.0",
        domain: AssemblyDomain = .electronics
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle.isEmpty ? description : subtitle
        self.category = category
        self.difficulty = difficulty
        self.estimatedMinutes = estimatedMinutes
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.imageName = imageName
        self.isActive = isActive
        self.nextAction = nextAction
        self.description = description.isEmpty ? subtitle : description
        self.components = components
        self.steps = steps
        self.schemaVersion = schemaVersion
        self.domain = domain
    }
    
    /// Compatibility initializer for tests and legacy call sites.
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: String,
        difficulty: String,
        estimatedDurationMinutes: Int,
        completedSteps: Int = 0,
        totalSteps: Int,
        steps: [ProjectStepSummary] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = description
        self.category = category
        self.difficulty = Difficulty(rawValue: difficulty) ?? .beginner
        self.estimatedMinutes = estimatedDurationMinutes
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.imageName = nil
        self.isActive = false
        self.nextAction = nil
        self.description = description
        self.components = []
        self.steps = steps
        self.schemaVersion = "1.0.0"
        self.domain = .electronics
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
nonisolated struct ActivityItemModel: Identifiable, Hashable, Codable, Sendable {
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
