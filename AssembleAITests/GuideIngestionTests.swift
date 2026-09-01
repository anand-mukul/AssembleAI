//
//  GuideIngestionTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class GuideIngestionTests: XCTestCase {
    
    private let parser = MarkdownGuideParser()
    
    // MARK: - Markdown Parser: Basic Structure
    
    func testParseMinimalMarkdownGuide() throws {
        let markdown = """
        # My LED Project
        
        A simple LED circuit tutorial.
        
        ## Step 1: Insert Resistor
        Place the 220 ohm resistor into the breadboard.
        
        ## Step 2: Insert LED
        Place the red LED with the long lead in Row 12.
        """
        
        let result = try parser.parse(text: markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.title, "My LED Project")
        XCTAssertEqual(result.project.steps.count, 2)
        XCTAssertEqual(result.project.steps[0].stepOrder, 1)
        XCTAssertEqual(result.project.steps[0].title, "Insert Resistor")
        XCTAssertEqual(result.project.steps[1].stepOrder, 2)
        XCTAssertEqual(result.project.steps[1].title, "Insert LED")
        XCTAssertTrue(result.project.steps[0].instruction.contains("220 ohm"))
        XCTAssertEqual(result.project.domain, .electronics)
    }
    
    func testParseMarkdownWithComponentsSection() throws {
        let markdown = """
        # Sensor Circuit
        
        ## Components
        - NTC Thermistor — 10K ohm sensor
        - 10K Resistor — 1% metal film
        - Breadboard — Half-size
        - Jumper Wires — Male-to-male (x3)
        
        ## Step 1: Place Thermistor
        Insert the thermistor leads into pins A5 and A10.
        """
        
        let result = try parser.parse(text: markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.components.count, 4)
        XCTAssertEqual(result.project.components[0].name, "NTC Thermistor")
        XCTAssertEqual(result.project.components[0].detail, "10K ohm sensor")
        XCTAssertEqual(result.project.components[3].name, "Jumper Wires")
        XCTAssertEqual(result.project.components[3].quantity, 3)
        XCTAssertEqual(result.project.steps.count, 1)
    }
    
    func testParseMarkdownWithAlternativeBOMHeadings() throws {
        let headings = ["## Parts", "## Materials", "## Bill of Materials", "## You Will Need", "## What You Need"]
        
        for heading in headings {
            let markdown = """
            # Test
            
            \(heading)
            - Part A — detail
            
            ## Step 1: Do something
            Instructions here.
            """
            
            let result = try parser.parse(text: markdown, domain: .electronics)
            XCTAssertEqual(result.project.components.count, 1, "Failed for heading: \(heading)")
        }
    }
    
    func testParseMarkdownWithWarningBlockquotes() throws {
        let markdown = """
        # Circuit Build
        
        ## Step 1: Insert Capacitor
        Place the capacitor into the C2 header slot.
        
        > **Warning**: Make sure the white stripe faces the GND rail. Reversed polarity can damage the capacitor.
        
        ## Step 2: Connect Wire
        Attach jumper wire.
        """
        
        let result = try parser.parse(text: markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.steps.count, 2)
        XCTAssertEqual(result.project.steps[0].commonMistakes.count, 1)
        XCTAssertTrue(result.project.steps[0].commonMistakes[0].explanation.contains("polarity"))
        XCTAssertEqual(result.project.steps[0].commonMistakes[0].severity, .moderate)
    }
    
    func testParseMarkdownWithCautionBlockquote() throws {
        let markdown = """
        # Build
        
        ## Step 1: Power On
        Switch on the power supply.
        
        > **Caution**: Short circuits can cause component damage.
        """
        
        let result = try parser.parse(text: markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.steps[0].commonMistakes.count, 1)
        XCTAssertEqual(result.project.steps[0].commonMistakes[0].severity, .critical)
    }
    
    // MARK: - Quantity Parsing
    
    func testParseComponentQuantityFormats() throws {
        let markdown = """
        # Test
        
        ## Components
        - Screws — M4 zinc (x6)
        - Dowels — 8mm beech (qty: 12)
        - Bolts — M6 (quantity: 4)
        - Single Part — one piece
        
        ## Step 1: Assemble
        Put it together.
        """
        
        let result = try parser.parse(text: markdown, domain: .physical)
        
        XCTAssertEqual(result.project.components[0].quantity, 6)
        XCTAssertEqual(result.project.components[1].quantity, 12)
        XCTAssertEqual(result.project.components[2].quantity, 4)
        XCTAssertEqual(result.project.components[3].quantity, 1)
    }
    
    // MARK: - Step Title Cleaning
    
    func testStepTitleCleaningVariations() throws {
        let markdown = """
        # Project
        
        ## Step 1: First Step
        Do first thing.
        
        ## 2. Second Step
        Do second thing.
        
        ## 3: Third Step
        Do third thing.
        
        ## Fourth Step
        Do fourth thing.
        """
        
        let result = try parser.parse(text: markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.steps.count, 4)
        XCTAssertEqual(result.project.steps[0].title, "First Step")
        XCTAssertEqual(result.project.steps[1].title, "Second Step")
        XCTAssertEqual(result.project.steps[2].title, "Third Step")
        XCTAssertEqual(result.project.steps[3].title, "Fourth Step")
    }
    
    // MARK: - Difficulty Inference
    
    func testDifficultyInference() throws {
        // Simple project: 2 steps, 0 components = beginner
        let simple = """
        # Simple
        ## Step 1: A
        Do A.
        ## Step 2: B
        Do B.
        """
        let simpleResult = try parser.parse(text: simple, domain: .electronics)
        XCTAssertEqual(simpleResult.project.difficulty, .beginner)
        
        // Complex project: 10 steps = advanced
        var complexLines = ["# Complex Project", "## Components"]
        for i in 1...5 { complexLines.append("- Part \(i) — detail") }
        for i in 1...10 { complexLines.append("## Step \(i): Action \(i)"); complexLines.append("Do step \(i).") }
        
        let complexResult = try parser.parse(text: complexLines.joined(separator: "\n"), domain: .electronics)
        XCTAssertEqual(complexResult.project.difficulty, .advanced)
    }
    
    // MARK: - Physical Domain
    
    func testParsePhysicalDomainProject() throws {
        let markdown = """
        # Bookshelf Assembly
        
        Assemble a 3-tier modular bookshelf.
        
        ## Materials
        - Side Panel — Melamine board 800mm (x2)
        - Shelf Board — 600mm (x3)
        - Wooden Dowels — 8mm (x12)
        
        ## Step 1: Insert Dowels
        Press dowels into the pre-drilled holes on each side panel.
        
        ## Step 2: Attach Bottom Shelf
        Align the shelf with the lowest pair of dowel holes.
        
        > **Warning**: Make sure the shelf is level before locking the cam disc.
        """
        
        let result = try parser.parse(text: markdown, domain: .physical)
        
        XCTAssertEqual(result.project.domain, .physical)
        XCTAssertEqual(result.project.category, "Assembly")
        XCTAssertEqual(result.project.components.count, 3)
        XCTAssertEqual(result.project.components[2].quantity, 12)
        XCTAssertEqual(result.project.steps.count, 2)
        XCTAssertEqual(result.project.steps[1].commonMistakes.count, 1)
    }
    
    // MARK: - Error Cases
    
    func testParseEmptyTextThrows() {
        XCTAssertThrowsError(try parser.parse(text: "", domain: .electronics)) { error in
            guard case GuideIngestionError.emptyInput = error else {
                XCTFail("Expected emptyInput error")
                return
            }
        }
    }
    
    func testParseTextWithoutStepsThrows() {
        let markdown = """
        # Project Title
        
        Just a description, no steps.
        """
        
        XCTAssertThrowsError(try parser.parse(text: markdown, domain: .electronics)) { error in
            guard case GuideIngestionError.noStepsExtracted = error else {
                XCTFail("Expected noStepsExtracted error")
                return
            }
        }
    }
    
    // MARK: - Confidence Scoring
    
    func testConfidenceIsHigherForCompleteGuides() throws {
        let minimal = """
        # Test
        ## Step 1: Do
        Do it.
        """
        
        let complete = """
        # Complete Project
        
        A thorough guide with components and multiple steps.
        
        ## Components
        - Part A — detail a
        - Part B — detail b
        
        ## Step 1: First
        First instruction.
        
        ## Step 2: Second
        Second instruction.
        
        ## Step 3: Third
        Third instruction.
        """
        
        let minimalResult = try parser.parse(text: minimal, domain: .electronics)
        let completeResult = try parser.parse(text: complete, domain: .electronics)
        
        XCTAssertGreaterThan(completeResult.confidence, minimalResult.confidence)
    }
    
    // MARK: - Deterministic Fallback
    
    func testDeterministicFallbackPlainText() async throws {
        let fallback = DeterministicIngestionFallback()
        
        let text = """
        Building an LED Circuit
        Insert the 220 ohm resistor into Row 10.
        Place the red LED into Row 12A.
        Connect jumper wire to GND rail.
        """
        
        let result = try await fallback.ingest(text: text, format: .plainText, domain: .electronics)
        
        XCTAssertEqual(result.project.title, "Building an LED Circuit")
        XCTAssertEqual(result.project.steps.count, 3)
        XCTAssertTrue(result.project.steps[0].instruction.contains("220 ohm"))
        XCTAssertLessThan(result.confidence, 0.6, "Plain text should have lower confidence")
    }
    
    func testDeterministicFallbackMarkdownText() async throws {
        let fallback = DeterministicIngestionFallback()
        
        let markdown = """
        # Motor Controller
        
        ## Components
        - DC Motor — 5V
        - L298N — Motor driver board
        
        ## Step 1: Wire Motor
        Connect motor leads to driver output pins.
        """
        
        let result = try await fallback.ingest(text: markdown, format: .markdown, domain: .electronics)
        
        XCTAssertEqual(result.project.title, "Motor Controller")
        XCTAssertEqual(result.project.components.count, 2)
        XCTAssertEqual(result.project.steps.count, 1)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    // MARK: - Ingestion Prompt Construction
    
    func testPromptContainsDomainAndSchema() {
        let prompt = GuideIngestionPrompts.buildExtractionPrompt(
            guideText: "Test guide text",
            format: .markdown,
            domain: .electronics
        )
        
        XCTAssertTrue(prompt.contains("Electronics"))
        XCTAssertTrue(prompt.contains("schema_version"))
        XCTAssertTrue(prompt.contains("visual_contract"))
        XCTAssertTrue(prompt.contains("resistor"))
        XCTAssertTrue(prompt.contains("GUIDE TEXT:"))
        XCTAssertTrue(prompt.contains("Test guide text"))
    }
    
    func testPromptPhysicalDomainContainsFurnitureTypes() {
        let prompt = GuideIngestionPrompts.buildExtractionPrompt(
            guideText: "Shelf assembly",
            format: .plainText,
            domain: .physical
        )
        
        XCTAssertTrue(prompt.contains("Physical"))
        XCTAssertTrue(prompt.contains("screw"))
        XCTAssertTrue(prompt.contains("dowel"))
        XCTAssertTrue(prompt.contains("cam_lock"))
    }
    
    // MARK: - Factory
    
    func testIngestionServiceFactoryReturnsService() {
        let service = GuideIngestionServiceFactory.resolve()
        XCTAssertNotNil(service)
    }
}
