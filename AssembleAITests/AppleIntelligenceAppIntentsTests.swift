//
//  AppleIntelligenceAppIntentsTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

#if canImport(AppIntents)
import AppIntents
#endif

@MainActor
final class AppleIntelligenceAppIntentsTests: XCTestCase {
    
    // MARK: - Test 1: Structured Tutor Feedback Model Serialization
    func testStructuredTutorFeedbackCodable() throws {
        let feedback = StructuredTutorFeedback(
            spokenMessage: "Shift the resistor lead one row down to Row 15.",
            targetHoleCoordinates: ["15E", "17E"],
            isUrgentCorrection: true,
            suggestedAction: "Move lead from 14E to 15E.",
            confidenceScore: 0.98
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(feedback)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StructuredTutorFeedback.self, from: data)
        
        XCTAssertEqual(decoded, feedback)
        XCTAssertEqual(decoded.targetHoleCoordinates, ["15E", "17E"])
        XCTAssertTrue(decoded.isUrgentCorrection)
    }
    
    // MARK: - Test 2: Foundation Models Tool Calling Service
    func testToolCallingServiceEvaluation() {
        let toolService = FoundationModelsToolCallingService()
        let step = AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Place 220 Ohm Resistor",
            instruction: "Insert between 10A and 15A"
        )
        let contract = VisualContract(
            pinPlacements: [
                PinPlacement(
                    partId: "resistor_220",
                    fromPin: PinConnection(componentId: "resistor_220", pinId: "1", row: "10", column: "A", role: .anode),
                    toPin: PinConnection(componentId: "resistor_220", pinId: "2", row: "15", column: "A", role: .cathode),
                    targetBoundingBox: nil
                )
            ]
        )
        let observed = ObservedAssemblyState(
            detectedComponents: [ObservedComponent(identifier: "resistor_220", name: "220 Ohm Resistor", confidence: 0.92)],
            detectedPositions: [ComponentPlacement(componentID: "resistor_220", detectedDescription: "10A to 15A", confidence: 0.95)],
            overallConfidence: 0.92
        )
        
        let outcome = toolService.queryPinPlacement(step: step, contract: contract, observedState: observed)
        XCTAssertTrue(outcome.isCorrect)
        XCTAssertEqual(outcome.status, .correct)
    }
    
    // MARK: - Test 3: Hybrid Tutor Response Provider Structured Feedback
    func testHybridTutorStructuredFeedback() async {
        let hybrid = HybridTutorResponseProvider()
        let step = AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Test Step", instruction: "Instruction")
        let context = AssistantContext(currentStep: step)
        let decision = InterventionDecision(action: .confirm(step: step), reason: "Completed")
        
        let feedback = await hybrid.generateStructuredFeedback(for: decision, context: context)
        XCTAssertFalse(feedback.spokenMessage.isEmpty)
        XCTAssertFalse(feedback.isUrgentCorrection)
    }
    
    // MARK: - Test 4: Mock Provider Structured Feedback
    func testMockProviderStructuredFeedback() async {
        let mock = MockConversationalTutorProvider()
        let step = AssemblyStep(projectId: UUID(), stepOrder: 1, title: "Mock Step", instruction: "Mock Instruction")
        let context = AssistantContext(currentStep: step)
        let decision = InterventionDecision(action: .instruct(step: step), reason: "Start")
        
        let feedback = await mock.generateStructuredFeedback(for: decision, context: context)
        XCTAssertEqual(feedback.spokenMessage, "Mock Structured Feedback")
        XCTAssertEqual(feedback.targetHoleCoordinates, ["15E", "17E"])
    }
    
    #if canImport(AppIntents)
    // MARK: - Test 5: Assembly Project Entity & Query Resolution
    @available(iOS 16.0, *)
    func testAssemblyProjectEntityQuery() async throws {
        let query = AssemblyProjectQuery()
        let allProjects = BundledProjectRepository.bundledProjects
        guard let first = allProjects.first else {
            XCTFail("No bundled projects found")
            return
        }
        
        let entities = try await query.entities(for: [first.id])
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.title, first.title)
        
        let suggested = try await query.suggestedEntities()
        XCTAssertGreaterThanOrEqual(suggested.count, 1)
    }
    
    // MARK: - Test 6: Assembly Step Entity & Query Resolution
    @available(iOS 16.0, *)
    func testAssemblyStepEntityQuery() async throws {
        let query = AssemblyStepQuery()
        let allSteps = BundledProjectRepository.bundledProjects.flatMap(\.steps)
        guard let first = allSteps.first else {
            XCTFail("No bundled steps found")
            return
        }
        
        let entities = try await query.entities(for: [first.id])
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.stepOrder, first.stepOrder)
        
        let suggested = try await query.suggestedEntities()
        XCTAssertGreaterThanOrEqual(suggested.count, 1)
    }
    
    // MARK: - Test 7: Inspect Assembly Intent Execution
    @available(iOS 16.0, *)
    func testInspectAssemblyIntentExecution() async throws {
        let intent = InspectAssemblyIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
    
    // MARK: - Test 8: Query Next Step Intent Execution
    @available(iOS 16.0, *)
    func testQueryNextStepIntentExecution() async throws {
        let intent = QueryNextStepIntent(stepNumber: 1)
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
    
    // MARK: - Test 9: Verify Polarity Intent Execution
    @available(iOS 16.0, *)
    func testVerifyPolarityIntentExecution() async throws {
        let intent = VerifyPolarityIntent(componentName: "Electrolytic Capacitor")
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
    
    // MARK: - Test 10: App Shortcuts Provider Exposes Registered Shortcuts
    @available(iOS 16.0, *)
    func testAppShortcutsProviderDiscovery() {
        let shortcuts = AssembleAIShortcutsProvider.appShortcuts
        XCTAssertEqual(shortcuts.count, 3)
        XCTAssertTrue(shortcuts.contains { $0.shortTitle == "Inspect Assembly" })
        XCTAssertTrue(shortcuts.contains { $0.shortTitle == "Next Step" })
        XCTAssertTrue(shortcuts.contains { $0.shortTitle == "Check Polarity" })
    }
    #endif
}
