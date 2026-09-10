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
    
    var displayName: String { rawValue }
    
    @MainActor
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
    
    enum CodingKeys: String, CodingKey {
        case id, stepOrder, title, instruction, isCompleted, expectedDurationMinutes, visualContract, commonMistakes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.stepOrder = try container.decode(Int.self, forKey: .stepOrder)
        self.title = try container.decode(String.self, forKey: .title)
        self.instruction = try container.decodeIfPresent(String.self, forKey: .instruction) ?? ""
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.expectedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .expectedDurationMinutes) ?? 2
        self.visualContract = try container.decodeIfPresent(VisualContract.self, forKey: .visualContract)
        self.commonMistakes = try container.decodeIfPresent([CommonMistake].self, forKey: .commonMistakes) ?? []
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
    var completedSteps: Int
    let imageName: String?
    var isActive: Bool
    let nextAction: String?
    let description: String
    let components: [ComponentRequirement]
    let steps: [ProjectStepSummary]
    
    /// Schema version for forward-compatible package evolution.
    let schemaVersion: String
    
    /// Assembly domain (electronics, physical, or hybrid).
    let domain: AssemblyDomain
    
    /// Timestamp of most recent user interaction or progress.
    let lastWorkedOn: Date?
    
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
        domain: AssemblyDomain = .electronics,
        lastWorkedOn: Date? = nil
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
        self.lastWorkedOn = lastWorkedOn
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
        self.lastWorkedOn = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, category, difficulty, estimatedMinutes, totalSteps, completedSteps, imageName, isActive, nextAction, description, components, steps, schemaVersion, domain, lastWorkedOn
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        let desc = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.description = desc
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? desc
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General Assembly"
        self.difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .beginner
        self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 15
        let decodedSteps = try container.decodeIfPresent([ProjectStepSummary].self, forKey: .steps) ?? []
        self.steps = decodedSteps
        self.totalSteps = try container.decodeIfPresent(Int.self, forKey: .totalSteps) ?? max(1, decodedSteps.count)
        self.completedSteps = try container.decodeIfPresent(Int.self, forKey: .completedSteps) ?? 0
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        self.nextAction = try container.decodeIfPresent(String.self, forKey: .nextAction)
        self.components = try container.decodeIfPresent([ComponentRequirement].self, forKey: .components) ?? []
        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1.0.0"
        self.domain = try container.decodeIfPresent(AssemblyDomain.self, forKey: .domain) ?? .electronics
        self.lastWorkedOn = try container.decodeIfPresent(Date.self, forKey: .lastWorkedOn)
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
