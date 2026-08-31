//
//  ProjectPackageLoaderTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class ProjectPackageLoaderTests: XCTestCase {
    
    // MARK: - Schema Decoding Tests
    
    func testDecodeMinimalElectronicsProject() throws {
        let json = """
        {
          "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Test Project",
          "category": "Electronics",
          "difficulty": "Beginner",
          "estimated_minutes": 10,
          "total_steps": 1,
          "steps": [
            {
              "step_order": 1,
              "title": "Step One",
              "instruction": "Do the thing."
            }
          ]
        }
        """.data(using: .utf8)!
        
        let project = try ProjectPackageLoader.loadFromData(json, source: "test")
        
        XCTAssertEqual(project.title, "Test Project")
        XCTAssertEqual(project.domain, .electronics)
        XCTAssertEqual(project.schemaVersion, "1.0.0")
        XCTAssertEqual(project.steps.count, 1)
        XCTAssertEqual(project.steps[0].stepOrder, 1)
        XCTAssertEqual(project.steps[0].title, "Step One")
    }
    
    func testDecodePhysicalDomainProject() throws {
        let json = """
        {
          "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
          "schema_version": "1.0.0",
          "domain": "Physical",
          "title": "Bookshelf Assembly",
          "category": "Furniture",
          "difficulty": "Beginner",
          "estimated_minutes": 30,
          "total_steps": 2,
          "components": [
            {
              "name": "Side Panel",
              "detail": "Melamine board",
              "is_required": true,
              "part_id": "part_panel",
              "component_type": "panel",
              "quantity": 2
            }
          ],
          "steps": [
            {
              "step_order": 1,
              "title": "Insert Dowels",
              "instruction": "Press dowels into holes.",
              "visual_contract": {
                "required_component_ids": ["part_panel"],
                "spatial_placements": [
                  {
                    "part_id": "part_panel",
                    "location_description": "Left side panel holes",
                    "quantity": 6
                  }
                ]
              }
            },
            {
              "step_order": 2,
              "title": "Attach Shelf",
              "instruction": "Lock cam discs."
            }
          ]
        }
        """.data(using: .utf8)!
        
        let project = try ProjectPackageLoader.loadFromData(json, source: "test")
        
        XCTAssertEqual(project.domain, .physical)
        XCTAssertEqual(project.components.count, 1)
        XCTAssertEqual(project.components[0].partId, "part_panel")
        XCTAssertEqual(project.components[0].componentType, .panel)
        XCTAssertEqual(project.components[0].quantity, 2)
        
        XCTAssertNotNil(project.steps[0].visualContract)
        XCTAssertEqual(project.steps[0].visualContract?.spatialPlacements.count, 1)
        XCTAssertEqual(project.steps[0].visualContract?.spatialPlacements[0].quantity, 6)
        XCTAssertNil(project.steps[1].visualContract)
    }
    
    func testDecodeVisualContractWithPinPlacements() throws {
        let json = """
        {
          "id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Pin Test",
          "category": "Electronics",
          "difficulty": "Intermediate",
          "estimated_minutes": 5,
          "total_steps": 1,
          "steps": [
            {
              "step_order": 1,
              "title": "Place Resistor",
              "instruction": "Bridge 10E to 15F.",
              "visual_contract": {
                "required_component_ids": ["part_res_220"],
                "pin_placements": [
                  {
                    "part_id": "part_res_220",
                    "from_pin": { "row": "10", "column": "E" },
                    "to_pin": { "row": "15", "column": "F" },
                    "tolerance_mm": 2.5
                  }
                ],
                "orientation_constraints": [
                  {
                    "part_id": "part_res_220",
                    "rule": "Color bands face left",
                    "marker_type": "label_direction"
                  }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!
        
        let project = try ProjectPackageLoader.loadFromData(json, source: "test")
        let contract = try XCTUnwrap(project.steps[0].visualContract)
        
        XCTAssertEqual(contract.pinPlacements.count, 1)
        XCTAssertEqual(contract.pinPlacements[0].fromPin.row, "10")
        XCTAssertEqual(contract.pinPlacements[0].fromPin.column, "E")
        XCTAssertEqual(contract.pinPlacements[0].toPin.label, "15F")
        XCTAssertEqual(contract.pinPlacements[0].toleranceMm, 2.5)
        XCTAssertEqual(contract.orientationConstraints.count, 1)
        XCTAssertEqual(contract.orientationConstraints[0].markerType, .labelDirection)
        XCTAssertTrue(contract.hasElectronicsConstraints)
        XCTAssertFalse(contract.hasSpatialConstraints)
    }
    
    func testDecodeCommonMistakes() throws {
        let json = """
        {
          "id": "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Mistake Test",
          "category": "Electronics",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 1,
          "steps": [
            {
              "step_order": 1,
              "title": "Insert Resistor",
              "instruction": "Place resistor.",
              "common_mistakes": [
                {
                  "condition": "Wrong row",
                  "explanation": "Resistor is in Row 14.",
                  "correction_action": "Move to Row 15.",
                  "severity": "moderate"
                },
                {
                  "condition": "Short circuit",
                  "explanation": "Both leads same side.",
                  "correction_action": "Bridge center divider.",
                  "severity": "critical"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        
        let project = try ProjectPackageLoader.loadFromData(json, source: "test")
        
        XCTAssertEqual(project.steps[0].commonMistakes.count, 2)
        XCTAssertEqual(project.steps[0].commonMistakes[0].severity, .moderate)
        XCTAssertEqual(project.steps[0].commonMistakes[1].severity, .critical)
        XCTAssertEqual(project.steps[0].commonMistakes[0].correctionAction, "Move to Row 15.")
    }
    
    func testDecodeComponentPhysicalAttributes() throws {
        let json = """
        {
          "id": "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE",
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Attributes Test",
          "category": "Electronics",
          "difficulty": "Advanced",
          "estimated_minutes": 5,
          "total_steps": 1,
          "components": [
            {
              "name": "220 Ohm Resistor",
              "detail": "Carbon film",
              "is_required": true,
              "part_id": "part_res_220",
              "component_type": "resistor",
              "physical_attributes": {
                "color_bands": ["red", "red", "brown", "gold"],
                "polarity_sensitive": false,
                "package_type": "axial",
                "nominal_value": "220"
              }
            }
          ],
          "steps": [
            { "step_order": 1, "title": "Step", "instruction": "Do." }
          ]
        }
        """.data(using: .utf8)!
        
        let project = try ProjectPackageLoader.loadFromData(json, source: "test")
        let attrs = try XCTUnwrap(project.components[0].physicalAttributes)
        
        XCTAssertEqual(attrs.colorBands, ["red", "red", "brown", "gold"])
        XCTAssertFalse(attrs.polaritySensitive)
        XCTAssertEqual(attrs.packageType, "axial")
    }
    
    // MARK: - Round-Trip Encoding Tests
    
    func testRoundTripEncodeDecode() throws {
        let original = AssemblyProject(
            title: "Round Trip",
            category: "Test",
            difficulty: .intermediate,
            estimatedMinutes: 10,
            totalSteps: 1,
            steps: [
                ProjectStepSummary(
                    stepOrder: 1,
                    title: "Step 1",
                    instruction: "Test step.",
                    visualContract: VisualContract(
                        requiredComponentIds: ["part_a"],
                        pinPlacements: [
                            PinPlacement(
                                partId: "part_a",
                                fromPin: PinCoordinate(row: "5", column: "A"),
                                toPin: PinCoordinate(row: "10", column: "B")
                            )
                        ]
                    ),
                    commonMistakes: [
                        CommonMistake(condition: "test", explanation: "test mistake")
                    ]
                )
            ],
            schemaVersion: "1.0.0",
            domain: .electronics
        )
        
        let data = try ProjectPackageLoader.encode(original)
        let decoded = try ProjectPackageLoader.loadFromData(data, source: "round-trip")
        
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.domain, original.domain)
        XCTAssertEqual(decoded.schemaVersion, original.schemaVersion)
        XCTAssertEqual(decoded.steps.count, 1)
        XCTAssertNotNil(decoded.steps[0].visualContract)
        XCTAssertEqual(decoded.steps[0].visualContract?.pinPlacements.count, 1)
        XCTAssertEqual(decoded.steps[0].commonMistakes.count, 1)
    }
    
    // MARK: - Validation Error Tests
    
    func testValidationRejectsEmptyTitle() {
        let json = """
        {
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "  ",
          "category": "Test",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 1,
          "steps": [
            { "step_order": 1, "title": "Step", "instruction": "Do." }
          ]
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try ProjectPackageLoader.loadFromData(json)) { error in
            guard case ProjectPackageError.invalidSchema = error else {
                XCTFail("Expected invalidSchema error, got \(error)")
                return
            }
        }
    }
    
    func testValidationRejectsEmptySteps() {
        let json = """
        {
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "No Steps",
          "category": "Test",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 0,
          "steps": []
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try ProjectPackageLoader.loadFromData(json)) { error in
            guard case ProjectPackageError.emptySteps = error else {
                XCTFail("Expected emptySteps error, got \(error)")
                return
            }
        }
    }
    
    func testValidationRejectsDuplicateStepOrders() {
        let json = """
        {
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Dupe Steps",
          "category": "Test",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 2,
          "steps": [
            { "step_order": 1, "title": "A", "instruction": "A." },
            { "step_order": 1, "title": "B", "instruction": "B." }
          ]
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try ProjectPackageLoader.loadFromData(json)) { error in
            guard case ProjectPackageError.duplicateStepOrder = error else {
                XCTFail("Expected duplicateStepOrder error, got \(error)")
                return
            }
        }
    }
    
    func testValidationRejectsInvalidSchemaVersion() {
        let json = """
        {
          "schema_version": "v1",
          "domain": "Electronics",
          "title": "Bad Version",
          "category": "Test",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 1,
          "steps": [
            { "step_order": 1, "title": "Step", "instruction": "Do." }
          ]
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try ProjectPackageLoader.loadFromData(json)) { error in
            guard case ProjectPackageError.invalidSchema = error else {
                XCTFail("Expected invalidSchema error, got \(error)")
                return
            }
        }
    }
    
    func testValidationRejectsBOMReferenceViolation() {
        let json = """
        {
          "schema_version": "1.0.0",
          "domain": "Electronics",
          "title": "Bad Ref",
          "category": "Test",
          "difficulty": "Beginner",
          "estimated_minutes": 5,
          "total_steps": 1,
          "components": [
            {
              "name": "Resistor",
              "detail": "220 Ohm",
              "is_required": true,
              "part_id": "part_res_220"
            }
          ],
          "steps": [
            {
              "step_order": 1,
              "title": "Step",
              "instruction": "Do.",
              "visual_contract": {
                "required_component_ids": ["part_nonexistent"]
              }
            }
          ]
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try ProjectPackageLoader.loadFromData(json)) { error in
            guard case ProjectPackageError.missingBOMReference = error else {
                XCTFail("Expected missingBOMReference error, got \(error)")
                return
            }
        }
    }
    
    // MARK: - PinCoordinate Tests
    
    func testPinCoordinateParsingStandard() {
        let pin = PinCoordinate(pinString: "10E")
        XCTAssertNotNil(pin)
        XCTAssertEqual(pin?.row, "10")
        XCTAssertEqual(pin?.column, "E")
        XCTAssertEqual(pin?.label, "10E")
    }
    
    func testPinCoordinateParsingGND() {
        let pin = PinCoordinate(pinString: "GND+")
        XCTAssertNotNil(pin)
        XCTAssertEqual(pin?.row, "GND")
        XCTAssertEqual(pin?.column, "+")
    }
    
    func testPinCoordinateParsingVCC() {
        let pin = PinCoordinate(pinString: "VCC")
        XCTAssertNotNil(pin)
        XCTAssertEqual(pin?.row, "VCC")
    }
    
    func testPinCoordinateParsingEmpty() {
        let pin = PinCoordinate(pinString: "")
        XCTAssertNil(pin)
    }
    
    // MARK: - Diagnostic Tests
    
    func testDiagnoseFindsStepGaps() {
        let project = AssemblyProject(
            title: "Gap Project",
            category: "Test",
            difficulty: .beginner,
            estimatedMinutes: 5,
            totalSteps: 2,
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "A", instruction: "A."),
                ProjectStepSummary(stepOrder: 3, title: "C", instruction: "C.")
            ]
        )
        
        let issues = ProjectPackageValidator.diagnose(project)
        XCTAssertTrue(issues.contains(where: { $0.contains("Gap") }))
    }
    
    func testDiagnoseFindsStepCountMismatch() {
        let project = AssemblyProject(
            title: "Mismatch Project",
            category: "Test",
            difficulty: .beginner,
            estimatedMinutes: 5,
            totalSteps: 5,
            steps: [
                ProjectStepSummary(stepOrder: 1, title: "A", instruction: "A.")
            ]
        )
        
        let issues = ProjectPackageValidator.diagnose(project)
        XCTAssertTrue(issues.contains(where: { $0.contains("totalSteps") }))
    }
}
