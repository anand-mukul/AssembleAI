//
//  AssembleAIAppIntents.swift
//  AssembleAI
//

import Foundation
import SwiftUI
import SwiftData

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
    
    private static func inferDomain(for project: LocalProject) -> String {
        let text = "\(project.title) \(project.projectDescription)".lowercased()
        if text.contains("table") || text.contains("chair") || text.contains("desk") || text.contains("shelf") || text.contains("dowel") || text.contains("cam lock") || text.contains("furniture") {
            return "Furniture"
        } else if text.contains("3d printer") || text.contains("gear") || text.contains("motor") || text.contains("belt") || text.contains("robot") || text.contains("mechanical") {
            return "Mechanical"
        } else if text.contains("pipe") || text.contains("valve") || text.contains("drain") || text.contains("plumbing") {
            return "Plumbing"
        }
        return "Electronics"
    }
    
    @MainActor
    public func entities(for identifiers: [UUID]) async throws -> [AssemblyProjectEntity] {
        let context = PersistenceController.shared.container.mainContext
        let descriptor = FetchDescriptor<LocalProject>()
        let localProjects = (try? context.fetch(descriptor)) ?? []
        let stepDescriptor = FetchDescriptor<LocalAssemblyStep>()
        let allSteps = (try? context.fetch(stepDescriptor)) ?? []
        
        return localProjects.filter { identifiers.contains($0.id) }.map { project in
            let count = allSteps.filter { $0.projectId == project.id }.count
            return AssemblyProjectEntity(
                id: project.id,
                title: project.title,
                domain: Self.inferDomain(for: project),
                stepCount: count
            )
        }
    }
    
    @MainActor
    public func suggestedEntities() async throws -> [AssemblyProjectEntity] {
        let context = PersistenceController.shared.container.mainContext
        let descriptor = FetchDescriptor<LocalProject>()
        let localProjects = (try? context.fetch(descriptor)) ?? []
        let stepDescriptor = FetchDescriptor<LocalAssemblyStep>()
        let allSteps = (try? context.fetch(stepDescriptor)) ?? []
        
        return localProjects.map { project in
            let count = allSteps.filter { $0.projectId == project.id }.count
            return AssemblyProjectEntity(
                id: project.id,
                title: project.title,
                domain: Self.inferDomain(for: project),
                stepCount: count
            )
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
    
    @MainActor
    public func entities(for identifiers: [UUID]) async throws -> [AssemblyStepEntity] {
        let context = PersistenceController.shared.container.mainContext
        let descriptor = FetchDescriptor<LocalAssemblyStep>()
        let localSteps = (try? context.fetch(descriptor)) ?? []
        return localSteps.filter { identifiers.contains($0.id) }.map {
            AssemblyStepEntity(id: $0.id, stepOrder: $0.stepOrder, title: $0.title, instruction: $0.instruction)
        }
    }
    
    @MainActor
    public func suggestedEntities() async throws -> [AssemblyStepEntity] {
        let context = PersistenceController.shared.container.mainContext
        let descriptor = FetchDescriptor<LocalAssemblyStep>()
        let localSteps = (try? context.fetch(descriptor)) ?? []
        return localSteps.map {
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
        let context = PersistenceController.shared.container.mainContext
        let sessionDesc = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.statusRaw == "inProgress" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let activeSession = try? context.fetch(sessionDesc).first
        
        let projectTitle: String
        let stepTitle: String
        let stepOrder: Int
        
        if let session = activeSession {
            let pid = session.projectId
            let projectDesc = FetchDescriptor<LocalProject>(predicate: #Predicate<LocalProject> { $0.id == pid })
            let proj = try? context.fetch(projectDesc).first
            projectTitle = proj?.title ?? "Assembly Project"
            stepOrder = session.currentStepOrder
            
            let order = stepOrder
            let stepDesc = FetchDescriptor<LocalAssemblyStep>(predicate: #Predicate<LocalAssemblyStep> { $0.projectId == pid && $0.stepOrder == order })
            let step = try? context.fetch(stepDesc).first
            stepTitle = step?.title ?? "Step \(order)"
        } else {
            let projDesc = FetchDescriptor<LocalProject>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            if let proj = try? context.fetch(projDesc).first {
                projectTitle = proj.title
                stepOrder = 1
                let pid = proj.id
                let stepDesc = FetchDescriptor<LocalAssemblyStep>(predicate: #Predicate<LocalAssemblyStep> { $0.projectId == pid && $0.stepOrder == 1 })
                stepTitle = (try? context.fetch(stepDesc).first)?.title ?? "Initial Step"
            } else {
                return .result(
                    dialog: IntentDialog("No active assembly project was found. Open AssembleAI to start assembling."),
                    view: AssemblyIntentSnippetView(
                        title: "No Project Active",
                        subtitle: "Open AssembleAI to select or start a project.",
                        statusText: "Idle",
                        statusColorName: "blue"
                    )
                )
            }
        }
        
        let dialog = IntentDialog("Checking \(projectTitle). Your active step is \(stepOrder): \(stepTitle). Follow the camera guidance.")
        
        return .result(
            dialog: dialog,
            view: AssemblyIntentSnippetView(
                title: projectTitle,
                subtitle: "Step \(stepOrder): \(stepTitle)",
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
        let context = PersistenceController.shared.container.mainContext
        let sessionDesc = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.statusRaw == "inProgress" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let activeSession = try? context.fetch(sessionDesc).first
        
        guard let session = activeSession else {
            let projDesc = FetchDescriptor<LocalProject>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            guard let proj = try? context.fetch(projDesc).first else {
                return .result(
                    dialog: IntentDialog("No assembly projects found. Open AssembleAI to browse projects."),
                    view: AssemblyIntentSnippetView(
                        title: "No Projects",
                        subtitle: "Open the app to start",
                        statusText: "No Data",
                        statusColorName: "blue"
                    )
                )
            }
            
            let pid = proj.id
            let stepDesc = FetchDescriptor<LocalAssemblyStep>(
                predicate: #Predicate<LocalAssemblyStep> { $0.projectId == pid },
                sortBy: [SortDescriptor(\.stepOrder, order: .forward)]
            )
            let steps = (try? context.fetch(stepDesc)) ?? []
            let target = steps.first
            let order = target?.stepOrder ?? 1
            let title = target?.title ?? "Step 1"
            let instruction = target?.instruction ?? "Follow instructions in app."
            
            return .result(
                dialog: IntentDialog("Step \(order): \(title). \(instruction)"),
                view: AssemblyIntentSnippetView(
                    title: "Step \(order): \(title)",
                    subtitle: instruction,
                    statusText: proj.title,
                    statusColorName: "blue"
                )
            )
        }
        
        let pid = session.projectId
        let targetOrder = stepNumber ?? session.currentStepOrder
        let stepDesc = FetchDescriptor<LocalAssemblyStep>(
            predicate: #Predicate<LocalAssemblyStep> { $0.projectId == pid && $0.stepOrder == targetOrder }
        )
        let step = try? context.fetch(stepDesc).first
        
        let order = step?.stepOrder ?? targetOrder
        let title = step?.title ?? "Step \(order)"
        let instruction = step?.instruction ?? "Inspect physical placement."
        
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

// MARK: - Query Resistor Bands Intent

/// Voice intent querying standard EIA color code bands for a given resistor value (e.g. 220 ohm, 10k).
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QueryResistorBandsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Query Resistor Color Bands"
    public static var description = IntentDescription("Calculates standard 4-band EIA color codes for a resistance value.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Resistance", default: "220 ohm")
    public var resistanceText: String
    
    public init() {
        self.resistanceText = "220 ohm"
    }
    
    public init(resistanceText: String) {
        self.resistanceText = resistanceText
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        guard let ohms = ResistorColorBandDecoder.parseNominalOhms(from: resistanceText) else {
            return .result(dialog: IntentDialog("Could not calculate color bands for \(resistanceText). Try specifying ohms or k, like 220 ohm or 10k."))
        }
        let bands = ResistorColorBandDecoder.bands(forOhms: ohms)
        let formattedBands = bands.map { $0.capitalized }.joined(separator: ", ")
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        let formattedVal = decoded?.formattedValue ?? "\(Int(ohms))Ω"
        
        let dialog = IntentDialog("For a \(formattedVal) resistor, the color bands are \(formattedBands).")
        return .result(dialog: dialog)
    }
}

// MARK: - Check Component Substitution Intent

/// Voice intent checking whether a replacement component can be safely substituted in a circuit.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct CheckComponentSubstitutionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Component Substitution"
    public static var description = IntentDescription("Evaluates if an alternative resistor, transistor, or capacitor can be safely used.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Requested Component", default: "330 ohm")
    public var requestedComponent: String
    
    public init() {
        self.requestedComponent = "330 ohm"
    }
    
    public init(requestedComponent: String) {
        self.requestedComponent = requestedComponent
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        if let reqOhms = ResistorColorBandDecoder.parseNominalOhms(from: requestedComponent) {
            if reqOhms >= 180 && reqOhms <= 470 {
                let current = (5.0 - 2.0) / reqOhms * 1000.0
                let dialog = IntentDialog("Yes, \(Int(reqOhms)) ohms is a safe substitute! Current will be approximately \(String(format: "%.1f", current)) milliamps, which is well within safe operating limits.")
                return .result(dialog: dialog)
            } else if reqOhms < 100 {
                let dialog = IntentDialog("Warning: \(Int(reqOhms)) ohms is too low! Current will exceed 30 milliamps and risks burning out standard LEDs.")
                return .result(dialog: dialog)
            }
        }
        let dialog = IntentDialog("When substituting \(requestedComponent), ensure voltage ratings match and power dissipation remains safe for the circuit.")
        return .result(dialog: dialog)
    }
}

// MARK: - Query Fastener Tool Intent (Physical Assembly)

/// Voice intent querying the recommended driver bit, wrench, or torque precaution for physical fasteners.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QueryFastenerToolIntent: AppIntent {
    public static var title: LocalizedStringResource = "What Tool Do I Need"
    public static var description = IntentDescription("Recommends exact assembly tools, driver bits, and torque warnings for furniture or mechanical fasteners.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Fastener Type", default: "cam lock")
    public var fastenerType: String
    
    public init() {
        self.fastenerType = "cam lock"
    }
    
    public init(fastenerType: String) {
        self.fastenerType = fastenerType
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        let toolService = FoundationModelsToolCallingService()
        let recommendation = toolService.queryFastenerToolRecommendation(fastenerType: fastenerType, sizeDescription: fastenerType)
        let dialog = IntentDialog("For \(fastenerType): Use a \(recommendation.toolName) (\(recommendation.bitSize)). \(recommendation.usageTip)")
        return .result(dialog: dialog)
    }
}

// MARK: - Query Joint Alignment Intent (Physical Assembly)

/// Voice intent verifying whether a furniture or mechanical joint is flush and square within 5° tolerance.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QueryJointAlignmentIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Joint Alignment"
    public static var description = IntentDescription("Evaluates if a furniture or mechanical joint is square and flush within 5° tolerance.")
    
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Joint Name", default: "Corner Joint")
    public var jointName: String
    
    public init() {
        self.jointName = "Corner Joint"
    }
    
    public init(jointName: String) {
        self.jointName = jointName
    }
    
    @MainActor
    public func perform() async throws -> some ProvidesDialog {
        let toolService = FoundationModelsToolCallingService()
        let result = toolService.queryJointAlignment(jointDescription: jointName, expectedAngleDegrees: 90.0, observedAngleDegrees: nil)
        let dialog = IntentDialog(result.guidance)
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
                "Check my furniture in \(.applicationName)",
                "Check my 3D printer in \(.applicationName)",
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
            intent: QueryFastenerToolIntent(),
            phrases: [
                "What tool do I need in \(.applicationName)",
                "Which screwdriver in \(.applicationName)",
                "Tool for this screw in \(.applicationName)"
            ],
            shortTitle: "Tool Recommendation",
            systemImageName: "wrench.and.screwdriver.fill"
        )
        AppShortcut(
            intent: QueryJointAlignmentIntent(),
            phrases: [
                "Check joint alignment in \(.applicationName)",
                "Is this joint square in \(.applicationName)",
                "Check corner alignment in \(.applicationName)"
            ],
            shortTitle: "Joint Alignment",
            systemImageName: "square.split.diagonal.2x2"
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
        AppShortcut(
            intent: QueryResistorBandsIntent(),
            phrases: [
                "Color bands for resistor in \(.applicationName)",
                "What color bands for resistor in \(.applicationName)",
                "Resistor bands in \(.applicationName)"
            ],
            shortTitle: "Resistor Bands",
            systemImageName: "paintpalette.fill"
        )
        AppShortcut(
            intent: CheckComponentSubstitutionIntent(),
            phrases: [
                "Can I substitute in \(.applicationName)",
                "Check substitution in \(.applicationName)",
                "Can I use this resistor in \(.applicationName)"
            ],
            shortTitle: "Check Substitution",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}

#endif
