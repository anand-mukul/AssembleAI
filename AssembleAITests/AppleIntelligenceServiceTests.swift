//
//  AppleIntelligenceServiceTests.swift
//  AssembleAITests
//
//  Unit tests verifying Apple Intelligence service capabilities,
//  NaturalLanguage entity extraction, and Spotlight indexing integration.
//

import XCTest
@testable import AssembleAI

final class AppleIntelligenceServiceTests: XCTestCase {
    
    // MARK: - Test 1: Apple Intelligence Capabilities Detection
    func testCapabilitiesDetection() async {
        let service = AppleIntelligenceService.shared
        let capabilities = await service.getCapabilities()
        
        XCTAssertFalse(capabilities.deviceModel.isEmpty)
        XCTAssertFalse(capabilities.osVersion.isEmpty)
        XCTAssertFalse(capabilities.summary.isEmpty)
        XCTAssertTrue(capabilities.supportsNaturalLanguageEmbedding)
    }
    
    // MARK: - Test 2: NaturalLanguage Entity Extraction
    func testNaturalLanguageEntityExtraction() async {
        let text = """
        How to build a simple LED circuit
        Components needed:
        1. 220 ohm resistor
        2. Red LED
        3. 830 tie-point breadboard
        4. Jumper wire
        
        Step 1: Place the 220 ohm resistor between row 10 and row 15.
        Step 2: Insert the LED anode into row 15.
        Step 3: Connect jumper wire to ground.
        """
        
        let service = AppleIntelligenceService.shared
        let (components, steps) = await service.extractStructuredEntities(from: text, domain: .electronics)
        
        XCTAssertGreaterThan(components.count, 0, "Should extract hardware components using NaturalLanguage keywords.")
        XCTAssertTrue(components.contains { $0.name == "Resistor" })
        XCTAssertTrue(components.contains { $0.name == "LED" })
        XCTAssertTrue(components.contains { $0.name == "Breadboard" })
        
        XCTAssertEqual(steps.count, 3, "Should extract all 3 sequential assembly steps.")
        XCTAssertEqual(steps[0].stepOrder, 1)
        XCTAssertEqual(steps[1].stepOrder, 2)
        XCTAssertEqual(steps[2].stepOrder, 3)
    }
    
    // MARK: - Test 3: Voice Intent Parser with NaturalLanguage
    func testVoiceIntentParserNaturalLanguage() {
        let parser = VoiceIntentParser()
        
        XCTAssertEqual(parser.parse("Could you repeat that?"), .repeatInstruction)
        XCTAssertEqual(parser.parse("Why is this wire red?"), .askWhy)
        XCTAssertEqual(parser.parse("Where should I put this LED?"), .askWhere)
        XCTAssertEqual(parser.parse("I'm totally stuck, can you help me?"), .requestHelp)
        XCTAssertEqual(parser.parse("Which side is the positive anode?"), .askPolarity)
        XCTAssertEqual(parser.parse("Did I do this right?"), .askIsCorrect)
        XCTAssertEqual(parser.parse("Let's continue to the next step"), .continueTask)
        XCTAssertEqual(parser.parse("Stop for a moment"), .stopTask)
    }
}
