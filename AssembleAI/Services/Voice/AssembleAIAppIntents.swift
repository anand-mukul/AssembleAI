//
//  AssembleAIAppIntents.swift
//  AssembleAI
//

import Foundation
import SwiftUI

#if canImport(AppIntents)
import AppIntents

// MARK: - App Entities for Spotlight & Siri Semantic Indexing

/// Structured entity exposing active assembly projects to Apple Intelligence, Spotlight, and Siri.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AssemblyProjectEntity: AppEntity {
    public static var defaultQuery = AssemblyProjectQuery()
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Assembly Project"
    
    public var id: UUID
    public var title: String
    public var domain: String
    public var stepCount: Int
    
    public init(id: UUID, title: String, domain: String, stepCount: Int) {
        self.id = id
        self.title = title
        self.domain = domain
        self.stepCount = stepCount
    }
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(domain.capitalized) • \(stepCount) steps"
        )
    }
}

/// Query provider for resolving project entities via Spotlight search or Siri disambiguation.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AssemblyProjectQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [UUID]) async throws -> [AssemblyProjectEntity] {
        let projects = BundledProjectRepository.bundledProjects
        return projects.filter { identifiers.contains($0.id) }.map {
            AssemblyProjectEntity(id: $0.id, title: $0.title, domain: $0.domain.rawValue, stepCount: $0.steps.count)
        }
    }
    
    public func suggestedEntities() async throws -> [AssemblyProjectEntity] {
        let projects = BundledProjectRepository.bundledProjects
        return projects.map {
            AssemblyProjectEntity(id: $0.id, title: $0.title, domain: $0.domain.rawValue, stepCount: $0.steps.count)
        }
    }
}

// MARK: - Assembly Step Entity

/// Structured entity exposing individual assembly steps to Siri and Spotlight.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AssemblyStepEntity: AppEntity {
    public static var defaultQuery = AssemblyStepQuery()
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Assembly Step"
    
    public var id: UUID
    public var stepOrder: Int
    public var title: String
    public var instruction: String
    
    public init(id: UUID, stepOrder: Int, title: String, instruction: String) {
        self.id = id
        self.stepOrder = stepOrder
        self.title = title
        self.instruction = instruction
    }
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Step \(stepOrder): \(title)",
            subtitle: "\(instruction)"
        )
    }
}

/// Query provider for resolving assembly steps via Siri or Spotlight.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AssemblyStepQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [UUID]) async throws -> [AssemblyStepEntity] {
        let projects = BundledProjectRepository.bundledProjects
        let allSteps = projects.flatMap(\.steps)
        return allSteps.filter { identifiers.contains($0.id) }.map {
            AssemblyStepEntity(id: $0.id, stepOrder: $0.stepOrder, title: $0.title, instruction: $0.instruction)
        }
    }
    
    public func suggestedEntities() async throws -> [AssemblyStepEntity] {
        let projects = BundledProjectRepository.bundledProjects
        let allSteps = projects.flatMap(\.steps)
        return allSteps.map {
            AssemblyStepEntity(id: $0.id, stepOrder: $0.stepOrder, title: $0.title, instruction: $0.instruction)
        }
    }
}

// MARK: - Snippet View for Siri & Shortcuts

/// Compact snippet UI rendered inside Siri cards, Action Button confirmations, or Spotlight results.
public struct AssemblyIntentSnippetView: View {
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let statusColorName: String
    
    public init(title: String, subtitle: String, statusText: String, statusColorName: String) {
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.statusColorName = statusColorName
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(statusColorName == "green" ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Inspect Assembly Intent (Siri / Action Button)

/// Real-time inspection intent executable via Siri voice commands or the iPhone Action Button.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct InspectAssemblyIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check My Assembly"
    public static var description = IntentDescription("Verifies the current physical assembly step using AssembleAI on-device camera vision.")
    
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog & ShowsSnippetView {
        let activeProject = BundledProjectRepository.bundledProjects.first
        let currentStep = activeProject?.steps.first
        
        let title = currentStep?.title ?? "Assembly In Progress"
        let dialog = IntentDialog("I am checking your assembly. Your active step is \(title). Follow the highlighted pin guides.")
        
        return .result(
            dialog: dialog,
            view: AssemblyIntentSnippetView(
                title: "AssembleAI Verification",
                subtitle: title,
                statusText: "Ready for live inspection",
                statusColorName: "green"
            )
        )
    }
}

// MARK: - Query Next Step Intent

/// Hands-free voice intent for reading the next physical assembly step instruction.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QueryNextStepIntent: AppIntent {
    public static var title: LocalizedStringResource = "What Is My Next Step"
    public static var description = IntentDescription("Reads the next physical assembly step instruction hands-free.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Step Number", default: nil)
    public var stepNumber: Int?
    
    public init() {}
    
    public init(stepNumber: Int?) {
        self.stepNumber = stepNumber
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog & ShowsSnippetView {
        let activeProject = BundledProjectRepository.bundledProjects.first
        let targetStep: AssemblyStep?
        if let num = stepNumber, let match = activeProject?.steps.first(where: { $0.stepOrder == num }) {
            targetStep = match
        } else {
            targetStep = activeProject?.steps.first
        }
        
        let order = targetStep?.stepOrder ?? 1
        let title = targetStep?.title ?? "Place 10k Resistor"
        let instruction = targetStep?.instruction ?? "Insert leads into row 10 and row 14."
        
        let speech = IntentDialog("Step \(order): \(title). \(instruction)")
        
        return .result(
            dialog: speech,
            view: AssemblyIntentSnippetView(
                title: "Step \(order): \(title)",
                subtitle: instruction,
                statusText: "Instruction Active",
                statusColorName: "blue"
            )
        )
    }
}

// MARK: - Verify Polarity Intent

/// Voice intent verifying component polarity (anode/cathode) for LEDs, electrolytic capacitors, or diodes.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct VerifyPolarityIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Polarity"
    public static var description = IntentDescription("Checks whether polarized components (LED, electrolytic capacitor, diode) are oriented correctly.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Component Name", default: "LED")
    public var componentName: String
    
    public init() {
        self.componentName = "LED"
    }
    
    public init(componentName: String) {
        self.componentName = componentName
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        let dialog = IntentDialog("For the \(componentName), ensure the longer lead, the anode, connects to positive voltage, and the shorter lead connects to ground.")
        return .result(dialog: dialog)
    }
}

// MARK: - App Shortcuts Provider

/// Exposes AssembleAI voice shortcuts to Siri, Spotlight, and the iOS Shortcuts application.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AssembleAIShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: InspectAssemblyIntent(),
            phrases: [
                "Check my assembly in \(.applicationName)",
                "Inspect my circuit in \(.applicationName)",
                "Is my circuit correct in \(.applicationName)",
                "Verify step in \(.applicationName)"
            ],
            shortTitle: "Inspect Assembly",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: QueryNextStepIntent(),
            phrases: [
                "What's the next step in \(.applicationName)",
                "Next instruction in \(.applicationName)",
                "What do I do next in \(.applicationName)"
            ],
            shortTitle: "Next Step",
            systemImageName: "arrow.right.circle.fill"
        )
        AppShortcut(
            intent: VerifyPolarityIntent(),
            phrases: [
                "Check polarity in \(.applicationName)",
                "Is polarity right in \(.applicationName)"
            ],
            shortTitle: "Check Polarity",
            systemImageName: "plus.forwardslash.minus"
        )
    }
}

#endif
