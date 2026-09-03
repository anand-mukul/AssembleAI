//
//  ResistorColorBandDecoderTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class ResistorColorBandDecoderTests: XCTestCase {
    
    // MARK: - 4-Band Resistor Decoding
    
    func testDecode220Ohm4Band() {
        // Red (2), Red (2), Brown (x10), Gold (5%)
        let bands = ["red", "red", "brown", "gold"]
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.ohms, 220.0)
        XCTAssertEqual(decoded?.tolerancePercent, 5.0)
        XCTAssertEqual(decoded?.formattedValue, "220Ω")
    }
    
    func testDecode10kOhm4Band() {
        // Brown (1), Black (0), Orange (x1,000), Gold (5%)
        let bands = ["brown", "black", "orange", "gold"]
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.ohms, 10_000.0)
        XCTAssertEqual(decoded?.tolerancePercent, 5.0)
        XCTAssertEqual(decoded?.formattedValue, "10kΩ")
    }
    
    func testDecode1kOhm4Band() {
        // Brown (1), Black (0), Red (x100), Gold (5%)
        let bands = ["brown", "black", "red", "gold"]
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.ohms, 1_000.0)
        XCTAssertEqual(decoded?.formattedValue, "1kΩ")
    }
    
    func testDecode4k7Ohm4Band() {
        // Yellow (4), Violet (7), Red (x100), Gold (5%)
        let bands = ["yellow", "violet", "red", "gold"]
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.ohms, 4_700.0)
        XCTAssertEqual(decoded?.formattedValue, "4.7kΩ")
    }
    
    // MARK: - 5-Band Precision Resistor Decoding
    
    func testDecode10kOhm5BandPrecision() {
        // Brown (1), Black (0), Black (0), Red (x100), Brown (1%)
        let bands = ["brown", "black", "black", "red", "brown"]
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.ohms, 10_000.0)
        XCTAssertEqual(decoded?.tolerancePercent, 1.0)
        XCTAssertEqual(decoded?.formattedValue, "10kΩ")
    }
    
    // MARK: - Nominal Ohms Parsing
    
    func testParseNominalOhms() {
        XCTAssertEqual(ResistorColorBandDecoder.parseNominalOhms(from: "220Ω"), 220.0)
        XCTAssertEqual(ResistorColorBandDecoder.parseNominalOhms(from: "220 ohm"), 220.0)
        XCTAssertEqual(ResistorColorBandDecoder.parseNominalOhms(from: "10k"), 10_000.0)
        XCTAssertEqual(ResistorColorBandDecoder.parseNominalOhms(from: "4.7kΩ"), 4_700.0)
        XCTAssertEqual(ResistorColorBandDecoder.parseNominalOhms(from: "1M"), 1_000_000.0)
    }
    
    // MARK: - Attribute Matching
    
    func testMatchesExpectedAttributesSuccess() {
        let expected = ComponentPhysicalAttributes(
            colorBands: ["red", "red", "brown", "gold"],
            nominalValue: "220Ω"
        )
        let result = ResistorColorBandDecoder.matches(
            detectedBands: ["red", "red", "brown", "gold"],
            expectedAttributes: expected
        )
        
        XCTAssertTrue(result.matches)
    }
    
    func testMatchesExpectedAttributesMismatch() {
        let expected = ComponentPhysicalAttributes(
            colorBands: ["red", "red", "brown", "gold"],
            nominalValue: "220Ω"
        )
        // Detected 10k instead
        let result = ResistorColorBandDecoder.matches(
            detectedBands: ["brown", "black", "orange", "gold"],
            expectedAttributes: expected
        )
        
        XCTAssertFalse(result.matches)
        XCTAssertTrue(result.explanation.contains("10kΩ"))
    }
    
    // MARK: - Color Classification
    
    func testColorClassificationRed() {
        let classified = ResistorBandColor.classify(r: 0.9, g: 0.1, b: 0.1)
        XCTAssertEqual(classified, .red)
    }
    
    func testColorClassificationBlack() {
        let classified = ResistorBandColor.classify(r: 0.05, g: 0.05, b: 0.05)
        XCTAssertEqual(classified, .black)
    }
}
