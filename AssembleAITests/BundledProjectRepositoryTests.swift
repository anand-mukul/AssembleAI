//
//  BundledProjectRepositoryTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class BundledProjectRepositoryTests: XCTestCase {
    
    // MARK: - Mock JSON Source Repository
    
    /// An in-memory project repository that loads from a provided JSON data array.
    private struct InMemoryJSONRepository: ProjectRepository {
        let jsonData: [Data]
        
        func fetchProjects() async throws -> [AssemblyProject] {
            return jsonData.compactMap { data in
                try? ProjectPackageLoader.loadFromData(data, source: "memory")
            }
        }
        
        func fetchRecentActivity() async throws -> [ActivityItemModel] {
            return []
        }
    }
    
    // MARK: - Tests
    
    func testFetchProjectsFromInMemoryJSON() async throws {
        let json1 = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "LED Circuit",
          "category": "Electronics",
          "difficulty": "Beginner",
          "estimated_minutes": 15,
          "total_steps": 1,
          "is_active": true,
          "steps": [
            { "step_order": 1, "title": "Insert Resistor", "instruction": "Bridge Row 10 to 15." }
          ]
        }
        """.data(using: .utf8)!
        
        let json2 = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "schema_version": "1.0.0",
          "domain": "Physical",
          "title": "Bookshelf",
          "category": "Furniture",
          "difficulty": "Beginner",
          "estimated_minutes": 35,
          "total_steps": 1,
          "steps": [
            { "step_order": 1, "title": "Insert Dowels", "instruction": "Press dowels." }
          ]
        }
        """.data(using: .utf8)!
        
        let repo = InMemoryJSONRepository(jsonData: [json1, json2])
        let projects = try await repo.fetchProjects()
        
        XCTAssertEqual(projects.count, 2)
        XCTAssertTrue(projects.contains(where: { $0.domain == .electronics }))
        XCTAssertTrue(projects.contains(where: { $0.domain == .physical }))
    }
    
    func testFetchProjectByIdReturnsCorrectProject() async throws {
        let targetId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        
        let json = """
        {
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Target Project",
          "category": "Electronics",
          "difficulty": "Intermediate",
          "estimated_minutes": 20,
          "total_steps": 1,
          "steps": [
            { "step_order": 1, "title": "Step", "instruction": "Do." }
          ]
        }
        """.data(using: .utf8)!
        
        let repo = InMemoryJSONRepository(jsonData: [json])
        let project = try await repo.fetchProject(byId: targetId)
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.title, "Target Project")
        XCTAssertEqual(project?.id, targetId)
    }
    
    func testFetchProjectByIdReturnsNilForUnknownId() async throws {
        let json = """
        {
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Existing Project",
          "category": "Electronics",
          "difficulty": "Beginner",
          "estimated_minutes": 10,
          "total_steps": 1,
          "steps": [
            { "step_order": 1, "title": "Step", "instruction": "Do." }
          ]
        }
        """.data(using: .utf8)!
        
        let repo = InMemoryJSONRepository(jsonData: [json])
        let project = try await repo.fetchProject(byId: UUID())
        
        XCTAssertNil(project)
    }
    
    func testMockProjectRepositoryStillWorks() async throws {
        let repo = MockProjectRepository()
        let projects = try await repo.fetchProjects()
        
        XCTAssertGreaterThan(projects.count, 0, "MockProjectRepository should return sample projects.")
        
        let activity = try await repo.fetchRecentActivity()
        XCTAssertGreaterThan(activity.count, 0, "MockProjectRepository should return sample activity.")
    }
    
    func testProjectRepositoryFactoryReturnsRepository() {
        let repo = ProjectRepositoryFactory.resolve()
        XCTAssertNotNil(repo)
    }
    
    func testProjectRepositoryFactoryMockReturnsCorrectType() {
        let repo = ProjectRepositoryFactory.mock()
        XCTAssertTrue(repo is MockProjectRepository)
    }
    
    // MARK: - VisualContract to ExpectedAssemblyState Conversion
    
    func testExpectedAssemblyStateFromVisualContract() {
        let contract = VisualContract(
            requiredComponentIds: ["part_res_220"],
            pinPlacements: [
                PinPlacement(
                    partId: "part_res_220",
                    fromPin: PinCoordinate(row: "10", column: "E"),
                    toPin: PinCoordinate(row: "15", column: "F")
                )
            ]
        )
        
        let stepSummary = ProjectStepSummary(
            stepOrder: 1,
            title: "Insert Resistor",
            instruction: "Place resistor.",
            visualContract: contract
        )
        
        let state = ExpectedAssemblyState.forStepSummary(stepSummary, projectId: UUID())
        
        XCTAssertEqual(state.requiredComponents.count, 1)
        XCTAssertEqual(state.requiredComponents[0].identifier, "part_res_220")
        XCTAssertEqual(state.requiredConnections.count, 1)
        XCTAssertEqual(state.requiredConnections[0].from, "10E")
        XCTAssertEqual(state.requiredConnections[0].to, "15F")
        XCTAssertEqual(state.requiredPositions.count, 1)
        XCTAssertTrue(state.requiredPositions[0].targetDescription.contains("10E"))
    }
    
    func testExpectedAssemblyStateFallbackWithoutContract() {
        let stepSummary = ProjectStepSummary(
            stepOrder: 3,
            title: "Connect Wire",
            instruction: "Attach wire."
        )
        
        let state = ExpectedAssemblyState.forStepSummary(stepSummary, projectId: UUID())
        
        XCTAssertEqual(state.requiredComponents.count, 1)
        XCTAssertEqual(state.requiredComponents[0].name, "Connect Wire")
    }
}
