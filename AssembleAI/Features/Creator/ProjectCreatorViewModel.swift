//
//  ProjectCreatorViewModel.swift
//  AssembleAI
//

import Foundation
import Combine

/// Orchestrates manual project creation and AI-assisted guide import.
///
/// Manages the multi-step creation flow:
/// 1. **Metadata** — title, domain, difficulty, description
/// 2. **Components** — bill of materials entries
/// 3. **Steps** — sequential assembly instructions
/// 4. **Review** — preview and save
@MainActor
final class ProjectCreatorViewModel: ObservableObject {
    
    // MARK: - Creation Mode
    
    enum CreationMode: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case importGuide = "Import Guide"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .manual: return "pencil.and.list.clipboard"
            case .importGuide: return "doc.text.magnifyingglass"
            }
        }
        
        var description: String {
            switch self {
            case .manual: return "Create each step manually"
            case .importGuide: return "Paste a guide or tutorial"
            }
        }
    }
    
    enum CreatorStep: Int, CaseIterable {
        case metadata = 0
        case components = 1
        case steps = 2
        case review = 3
        
        var title: String {
            switch self {
            case .metadata: return "Details"
            case .components: return "Components"
            case .steps: return "Steps"
            case .review: return "Review"
            }
        }
    }
    
    // MARK: - Published State
    
    @Published var creationMode: CreationMode = .manual
    @Published var currentStep: CreatorStep = .metadata
    
    // Metadata
    @Published var projectTitle: String = ""
    @Published var projectDescription: String = ""
    @Published var selectedDomain: AssemblyDomain = .electronics
    @Published var selectedDifficulty: Difficulty = .beginner
    @Published var estimatedMinutes: Int = 15
    
    // Components
    @Published var components: [EditableComponent] = []
    
    // Steps
    @Published var assemblySteps: [EditableStep] = []
    
    // Import
    @Published var importText: String = ""
    @Published var selectedFormat: GuideSourceFormat = .markdown
    @Published var isIngesting: Bool = false
    @Published var ingestionResult: IngestionResult?
    @Published var ingestionError: String?
    
    // Saving
    @Published var isSaving: Bool = false
    @Published var savedProject: AssemblyProject?
    @Published var saveError: String?
    
    // Validation
    @Published var validationErrors: [String] = []
    
    private let ingestionService: GuideIngestionServiceProtocol
    
    init(ingestionService: GuideIngestionServiceProtocol? = nil) {
        self.ingestionService = ingestionService ?? GuideIngestionServiceFactory.resolve()
    }
    
    // MARK: - Editable Models
    
    struct EditableComponent: Identifiable {
        let id: UUID
        var name: String
        var detail: String
        var quantity: Int
        var isRequired: Bool
        
        init(id: UUID = UUID(), name: String = "", detail: String = "", quantity: Int = 1, isRequired: Bool = true) {
            self.id = id
            self.name = name
            self.detail = detail
            self.quantity = quantity
            self.isRequired = isRequired
        }
        
        func toDomain() -> ComponentRequirement {
            ComponentRequirement(
                id: id,
                name: name,
                detail: detail.isEmpty ? name : detail,
                isRequired: isRequired,
                partId: "part_\(name.lowercased().replacingOccurrences(of: " ", with: "_").prefix(20))",
                quantity: quantity
            )
        }
    }
    
    struct EditableStep: Identifiable {
        let id: UUID
        var title: String
        var instruction: String
        var estimatedMinutes: Int
        
        init(id: UUID = UUID(), title: String = "", instruction: String = "", estimatedMinutes: Int = 2) {
            self.id = id
            self.title = title
            self.instruction = instruction
            self.estimatedMinutes = estimatedMinutes
        }
        
        func toDomain(order: Int) -> ProjectStepSummary {
            ProjectStepSummary(
                id: id,
                stepOrder: order,
                title: title,
                instruction: instruction,
                expectedDurationMinutes: estimatedMinutes
            )
        }
    }
    
    // MARK: - Navigation
    
    var canGoBack: Bool { currentStep.rawValue > 0 }
    var canGoForward: Bool { currentStep.rawValue < CreatorStep.allCases.count - 1 }
    var isOnReviewStep: Bool { currentStep == .review }
    
    func goForward() {
        guard canGoForward else { return }
        validateCurrentStep()
        if validationErrors.isEmpty, let next = CreatorStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func goBack() {
        if let prev = CreatorStep(rawValue: currentStep.rawValue - 1) {
            validationErrors = []
            currentStep = prev
        }
    }
    
    // MARK: - Component Management
    
    func addComponent() {
        components.append(EditableComponent())
    }
    
    func removeComponent(at offsets: IndexSet) {
        components.remove(atOffsets: offsets)
    }
    
    func moveComponent(from source: IndexSet, to destination: Int) {
        components.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Step Management
    
    func addStep() {
        let nextOrder = assemblySteps.count + 1
        assemblySteps.append(EditableStep(title: "Step \(nextOrder)"))
    }
    
    func removeStep(at offsets: IndexSet) {
        assemblySteps.remove(atOffsets: offsets)
    }
    
    func moveStep(from source: IndexSet, to destination: Int) {
        assemblySteps.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Import / Ingestion
    
    func startIngestion() async {
        let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            ingestionError = "Please paste guide text or a URL to import."
            return
        }
        
        isIngesting = true
        ingestionError = nil
        ingestionResult = nil
        
        do {
            let result = try await ingestionService.ingest(
                text: text,
                format: selectedFormat,
                domain: selectedDomain
            )
            
            ingestionResult = result
            
            // Populate form fields from parsed result
            applyIngestionResult(result)
            
        } catch {
            ingestionError = error.localizedDescription
        }
        
        isIngesting = false
    }
    
    /// Populates the manual creation form with data from an ingestion result.
    func applyIngestionResult(_ result: IngestionResult) {
        let project = result.project
        
        projectTitle = project.title
        projectDescription = project.description
        selectedDomain = project.domain
        selectedDifficulty = project.difficulty
        estimatedMinutes = project.estimatedMinutes
        
        components = project.components.map { comp in
            EditableComponent(
                id: comp.id,
                name: comp.name,
                detail: comp.detail,
                quantity: comp.quantity,
                isRequired: comp.isRequired
            )
        }
        
        assemblySteps = project.steps.map { step in
            EditableStep(
                id: step.id,
                title: step.title,
                instruction: step.instruction,
                estimatedMinutes: step.expectedDurationMinutes
            )
        }
        
        // Switch to manual mode for editing the imported data
        creationMode = .manual
        currentStep = .review
    }
    
    // MARK: - Validation
    
    func validateCurrentStep() {
        validationErrors = []
        
        switch currentStep {
        case .metadata:
            if projectTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors.append("Project title is required.")
            }
        case .components:
            let emptyNames = components.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            if !emptyNames.isEmpty {
                validationErrors.append("\(emptyNames.count) component(s) have empty names.")
            }
        case .steps:
            if assemblySteps.isEmpty {
                validationErrors.append("At least one assembly step is required.")
            }
            let emptyTitles = assemblySteps.filter { $0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            if !emptyTitles.isEmpty {
                validationErrors.append("\(emptyTitles.count) step(s) have empty titles.")
            }
        case .review:
            // Final validation
            if projectTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors.append("Project title is required.")
            }
            if assemblySteps.isEmpty {
                validationErrors.append("At least one assembly step is required.")
            }
        }
    }
    
    func validateAll() -> Bool {
        validationErrors = []
        
        if projectTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Project title is required.")
        }
        if assemblySteps.isEmpty {
            validationErrors.append("At least one assembly step is required.")
        }
        let emptyStepTitles = assemblySteps.filter { $0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        if !emptyStepTitles.isEmpty {
            validationErrors.append("\(emptyStepTitles.count) step(s) have empty titles.")
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Build & Save
    
    /// Builds the final `AssemblyProject` from form data.
    func buildProject() -> AssemblyProject {
        let domainComponents = components
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.toDomain() }
        
        let domainSteps = assemblySteps.enumerated().map { index, step in
            step.toDomain(order: index + 1)
        }
        
        return AssemblyProject(
            title: projectTitle.trimmingCharacters(in: .whitespaces),
            subtitle: String(projectDescription.prefix(100)),
            category: selectedDomain == .electronics ? "Electronics" : "Assembly",
            difficulty: selectedDifficulty,
            estimatedMinutes: estimatedMinutes,
            totalSteps: domainSteps.count,
            description: projectDescription,
            components: domainComponents,
            steps: domainSteps,
            domain: selectedDomain
        )
    }
    
    /// Saves the created project as a JSON package in the documents directory.
    func saveProject() async {
        guard validateAll() else { return }
        
        isSaving = true
        saveError = nil
        
        let project = buildProject()
        
        do {
            try ProjectPackageLoader.saveToDocuments(project)
            savedProject = project
        } catch {
            saveError = error.localizedDescription
        }
        
        isSaving = false
    }
}
