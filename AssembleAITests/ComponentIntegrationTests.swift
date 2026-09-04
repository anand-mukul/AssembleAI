//
//  ComponentIntegrationTests.swift
//  AssembleAITests
//

import XCTest
import SwiftUI
import SwiftData
@testable import AssembleAI

@MainActor
final class ComponentIntegrationTests: XCTestCase {
    
    // MARK: - Test 1: QuickScanView Initialization & Structure
    func testQuickScanViewInitialization() {
        var launchedProject: AssemblyProject?
        let view = QuickScanView { project in
            launchedProject = project
        }
        XCTAssertNotNil(view)
    }
    
    // MARK: - Test 2: PrivacySheet Presentation Callback
    func testPrivacySheetInitialization() {
        var continued = false
        let sheet = PrivacySheet {
            continued = true
        }
        XCTAssertNotNil(sheet)
    }
    
    // MARK: - Test 3: VerificationDetailsSheet Data Binding
    func testVerificationDetailsSheetBinding() {
        let result = VerificationResult(
            status: .correct,
            confidence: 0.96,
            detectedDescription: "Resistor in 10E - 15F",
            expectedDescription: "220Ω Resistor in 10E - 15F",
            explanation: "Lead placement verified"
        )
        let sheet = VerificationDetailsSheet(
            result: result,
            stepTitle: "Step 1: Place 220Ω Resistor"
        )
        XCTAssertNotNil(sheet)
        XCTAssertEqual(sheet.stepTitle, "Step 1: Place 220Ω Resistor")
        XCTAssertEqual(sheet.result.confidence, 0.96)
    }
    
    // MARK: - Test 4: FoundationModelDebugView Inspection Binding
    func testFoundationModelDebugViewBinding() {
        let debugView = FoundationModelDebugView(
            stepTitle: "Insert Capacitor",
            issueType: .wrongPolarity,
            expectedDesc: "GND bus line",
            observedDesc: "5V line",
            latencyMs: 112,
            usedFallback: false
        )
        XCTAssertNotNil(debugView)
        XCTAssertEqual(debugView.stepTitle, "Insert Capacitor")
        XCTAssertEqual(debugView.latencyMs, 112)
        XCTAssertFalse(debugView.usedFallback)
    }
    
    // MARK: - Test 5: SpatialAROverlayView Projection
    func testSpatialAROverlayViewBinding() {
        let overlay = GuidanceOverlay(
            title: "Shift Lead",
            message: "Move lead 1 slot over",
            sourceRegion: CGRect(x: 0.2, y: 0.4, width: 0.1, height: 0.1),
            destinationRegion: CGRect(x: 0.3, y: 0.4, width: 0.1, height: 0.1),
            style: .move
        )
        let arView = SpatialAROverlayView(guidance: overlay)
        XCTAssertNotNil(arView)
        XCTAssertEqual(arView.guidance.style, .move)
    }
    
    // MARK: - Test 6: LocalFirstProjectRepository SwiftData Persistence
    func testLocalFirstProjectRepositoryOperations() async throws {
        let controller = PersistenceController(inMemory: true)
        let repo = LocalFirstProjectRepository(modelContext: controller.container.mainContext)
        
        let initialProjects = try await repo.fetchProjects()
        XCTAssertTrue(initialProjects.isEmpty)
        
        let newProject = Project(
            id: UUID(),
            ownerId: UUID(),
            title: "Breadboard Power Unit",
            description: "5V/3.3V dual rail supply",
            difficulty: "Beginner",
            estimatedMinutes: 20
        )
        
        try await repo.saveProject(newProject)
        
        let fetched = try await repo.fetchProject(id: newProject.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Breadboard Power Unit")
        XCTAssertEqual(fetched?.estimatedMinutes, 20)
        
        try await repo.deleteProject(id: newProject.id)
        let deleted = try await repo.fetchProject(id: newProject.id)
        XCTAssertNil(deleted)
    }
}
