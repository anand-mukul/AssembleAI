//
//  ProjectCreatorTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class ProjectCreatorTests: XCTestCase {
    
    // MARK: - ViewModel Initialization
    
    func testViewModelDefaultState() {
        let vm = ProjectCreatorViewModel()
        
        XCTAssertEqual(vm.creationMode, .manual)
        XCTAssertEqual(vm.currentStep, .metadata)
        XCTAssertTrue(vm.projectTitle.isEmpty)
        XCTAssertTrue(vm.components.isEmpty)
        XCTAssertTrue(vm.assemblySteps.isEmpty)
        XCTAssertFalse(vm.isIngesting)
        XCTAssertFalse(vm.isSaving)
        XCTAssertNil(vm.savedProject)
    }
    
    // MARK: - Navigation
    
    func testNavigationForwardRequiresValidation() {
        let vm = ProjectCreatorViewModel()
        
        // Should not advance past metadata without a title
        vm.goForward()
        XCTAssertEqual(vm.currentStep, .metadata, "Should stay on metadata when title is empty")
        XCTAssertFalse(vm.validationErrors.isEmpty)
    }
    
    func testNavigationForwardWithValidTitle() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test Project"
        
        vm.goForward()
        XCTAssertEqual(vm.currentStep, .components)
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }
    
    func testNavigationBackFromComponents() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test"
        vm.goForward() // → components
        
        vm.goBack()
        XCTAssertEqual(vm.currentStep, .metadata)
    }
    
    func testNavigationFullFlow() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test Project"
        vm.addStep()
        vm.assemblySteps[0].title = "Step 1"
        
        vm.goForward() // → components
        XCTAssertEqual(vm.currentStep, .components)
        
        vm.goForward() // → steps
        XCTAssertEqual(vm.currentStep, .steps)
        
        vm.goForward() // → review
        XCTAssertEqual(vm.currentStep, .review)
        
        XCTAssertTrue(vm.isOnReviewStep)
        XCTAssertFalse(vm.canGoForward)
    }
    
    // MARK: - Component Management
    
    func testAddComponent() {
        let vm = ProjectCreatorViewModel()
        
        vm.addComponent()
        XCTAssertEqual(vm.components.count, 1)
        
        vm.addComponent()
        XCTAssertEqual(vm.components.count, 2)
    }
    
    func testRemoveComponent() {
        let vm = ProjectCreatorViewModel()
        vm.addComponent()
        vm.addComponent()
        
        vm.removeComponent(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.components.count, 1)
    }
    
    // MARK: - Step Management
    
    func testAddStep() {
        let vm = ProjectCreatorViewModel()
        
        vm.addStep()
        XCTAssertEqual(vm.assemblySteps.count, 1)
        XCTAssertEqual(vm.assemblySteps[0].title, "Step 1")
        
        vm.addStep()
        XCTAssertEqual(vm.assemblySteps.count, 2)
        XCTAssertEqual(vm.assemblySteps[1].title, "Step 2")
    }
    
    func testRemoveStep() {
        let vm = ProjectCreatorViewModel()
        vm.addStep()
        vm.addStep()
        vm.addStep()
        
        vm.removeStep(at: IndexSet(integer: 1))
        XCTAssertEqual(vm.assemblySteps.count, 2)
    }
    
    // MARK: - Validation
    
    func testValidateAllPassesWithCompleteData() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "LED Circuit"
        vm.addStep()
        vm.assemblySteps[0].title = "Insert Resistor"
        
        XCTAssertTrue(vm.validateAll())
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }
    
    func testValidateAllFailsWithEmptyTitle() {
        let vm = ProjectCreatorViewModel()
        vm.addStep()
        vm.assemblySteps[0].title = "Step 1"
        
        XCTAssertFalse(vm.validateAll())
        XCTAssertTrue(vm.validationErrors.contains(where: { $0.contains("title") }))
    }
    
    func testValidateAllFailsWithNoSteps() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test"
        
        XCTAssertFalse(vm.validateAll())
        XCTAssertTrue(vm.validationErrors.contains(where: { $0.contains("step") }))
    }
    
    func testValidateAllFailsWithEmptyStepTitles() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test"
        vm.addStep()
        vm.assemblySteps[0].title = ""
        
        XCTAssertFalse(vm.validateAll())
    }
    
    // MARK: - Build Project
    
    func testBuildProjectProducesValidAssemblyProject() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test Circuit"
        vm.projectDescription = "A test circuit."
        vm.selectedDomain = .electronics
        vm.selectedDifficulty = .intermediate
        vm.estimatedMinutes = 20
        
        vm.addComponent()
        vm.components[0].name = "Resistor"
        vm.components[0].detail = "220 ohm"
        vm.components[0].quantity = 2
        
        vm.addStep()
        vm.assemblySteps[0].title = "Insert Resistor"
        vm.assemblySteps[0].instruction = "Place into Row 10."
        
        vm.addStep()
        vm.assemblySteps[1].title = "Insert LED"
        vm.assemblySteps[1].instruction = "Place LED into Row 12."
        
        let project = vm.buildProject()
        
        XCTAssertEqual(project.title, "Test Circuit")
        XCTAssertEqual(project.domain, .electronics)
        XCTAssertEqual(project.difficulty, .intermediate)
        XCTAssertEqual(project.estimatedMinutes, 20)
        XCTAssertEqual(project.components.count, 1)
        XCTAssertEqual(project.components[0].quantity, 2)
        XCTAssertEqual(project.steps.count, 2)
        XCTAssertEqual(project.steps[0].stepOrder, 1)
        XCTAssertEqual(project.steps[1].stepOrder, 2)
        XCTAssertEqual(project.totalSteps, 2)
        XCTAssertEqual(project.schemaVersion, "1.0.0")
    }
    
    func testBuildProjectFiltersEmptyComponents() {
        let vm = ProjectCreatorViewModel()
        vm.projectTitle = "Test"
        vm.addComponent() // Empty name — should be filtered
        vm.addComponent()
        vm.components[1].name = "Valid Part"
        
        vm.addStep()
        vm.assemblySteps[0].title = "Step 1"
        
        let project = vm.buildProject()
        XCTAssertEqual(project.components.count, 1, "Empty-name components should be filtered out")
        XCTAssertEqual(project.components[0].name, "Valid Part")
    }
    
    // MARK: - Apply Ingestion Result
    
    func testApplyIngestionResultPopulatesForm() {
        let vm = ProjectCreatorViewModel()
        
        let project = AssemblyProject(
            title: "Imported Guide",
            subtitle: "From markdown",
            category: "Electronics",
            difficulty: .intermediate,
            estimatedMinutes: 25,
            totalSteps: 2,
            components: [
                ComponentRequirement(name: "LED", detail: "5mm red"),
                ComponentRequirement(name: "Resistor", detail: "220 ohm")
            ],
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "Step A", instruction: "Do A."),
                ProjectStepSummary(stepOrder: 2, title: "Step B", instruction: "Do B.")
            ],
            domain: .electronics
        )
        
        let result = IngestionResult(
            project: project,
            confidence: 0.85,
            warnings: [],
            sourceText: "test",
            processingTimeMs: 100
        )
        
        vm.applyIngestionResult(result)
        
        XCTAssertEqual(vm.projectTitle, "Imported Guide")
        XCTAssertEqual(vm.selectedDifficulty, .intermediate)
        XCTAssertEqual(vm.estimatedMinutes, 25)
        XCTAssertEqual(vm.components.count, 2)
        XCTAssertEqual(vm.assemblySteps.count, 2)
        XCTAssertEqual(vm.creationMode, .manual, "Should switch to manual for editing")
        XCTAssertEqual(vm.currentStep, .review, "Should jump to review after import")
    }
    
    // MARK: - Editable Model Conversion
    
    func testEditableComponentToDomain() {
        let editable = ProjectCreatorViewModel.EditableComponent(
            name: "Red LED",
            detail: "5mm diffuse",
            quantity: 3,
            isRequired: true
        )
        
        let domain = editable.toDomain()
        
        XCTAssertEqual(domain.name, "Red LED")
        XCTAssertEqual(domain.detail, "5mm diffuse")
        XCTAssertEqual(domain.quantity, 3)
        XCTAssertTrue(domain.isRequired)
        XCTAssertNotNil(domain.partId)
        XCTAssertTrue(domain.partId?.hasPrefix("part_") == true)
    }
    
    func testEditableStepToDomain() {
        let editable = ProjectCreatorViewModel.EditableStep(
            title: "Insert Resistor",
            instruction: "Place into Row 10 to Row 15.",
            estimatedMinutes: 3
        )
        
        let domain = editable.toDomain(order: 5)
        
        XCTAssertEqual(domain.stepOrder, 5)
        XCTAssertEqual(domain.title, "Insert Resistor")
        XCTAssertEqual(domain.instruction, "Place into Row 10 to Row 15.")
        XCTAssertEqual(domain.expectedDurationMinutes, 3)
    }
}
