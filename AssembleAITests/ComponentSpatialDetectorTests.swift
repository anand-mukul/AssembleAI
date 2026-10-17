//
//  ComponentSpatialDetectorTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class ComponentSpatialDetectorTests: XCTestCase {
    
    private var detector: ComponentSpatialDetector!
    
    override func setUp() {
        super.setUp()
        detector = ComponentSpatialDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - 1. Universal Fastener Specification Parsing
    
    func testFastenerSpecParsing() {
        let boltCase = detector.parseFastenerSpec(from: "M4x20 Bolt")
        XCTAssertNotNil(boltCase)
        XCTAssertEqual(boltCase?.type, .bolt)
        XCTAssertEqual(boltCase?.size, "M4X20")
        
        let screwCase = detector.parseFastenerSpec(from: "M3x12")
        XCTAssertNotNil(screwCase)
        XCTAssertEqual(screwCase?.type, .screw)
        XCTAssertEqual(screwCase?.size, "M3X12")
        
        let nutCase = detector.parseFastenerSpec(from: "M5 Hex Nut")
        XCTAssertNotNil(nutCase)
        XCTAssertEqual(nutCase?.type, .nut)
        
        let imperialCase = detector.parseFastenerSpec(from: "1/4-20")
        XCTAssertNotNil(imperialCase)
        XCTAssertEqual(imperialCase?.type, .bolt)
        XCTAssertEqual(imperialCase?.size, "1/4-20")
        
        let dowelCase = detector.parseFastenerSpec(from: "Wooden Dowel 8mm")
        XCTAssertNotNil(dowelCase)
        XCTAssertEqual(dowelCase?.type, .dowel)
        
        let camCase = detector.parseFastenerSpec(from: "Cam Lock Bolt")
        XCTAssertNotNil(camCase)
        XCTAssertEqual(camCase?.type, .camLock)
    }
    
    // MARK: - 2. Universal Structural & Framing Specification Parsing
    
    func testStructuralSpecParsing() {
        let railCase = detector.parseStructuralSpec(from: "2020 Aluminum Extrusion")
        XCTAssertNotNil(railCase)
        XCTAssertEqual(railCase?.type, .rail)
        
        let linearRailCase = detector.parseStructuralSpec(from: "Linear Rail MGN12H")
        XCTAssertNotNil(linearRailCase)
        XCTAssertEqual(linearRailCase?.type, .rail)
        
        let panelCase = detector.parseStructuralSpec(from: "Side Panel Shelf")
        XCTAssertNotNil(panelCase)
        XCTAssertEqual(panelCase?.type, .panel)
        
        let bracketCase = detector.parseStructuralSpec(from: "Corner Bracket")
        XCTAssertNotNil(bracketCase)
        XCTAssertEqual(bracketCase?.type, .bracket)
        
        let hingeCase = detector.parseStructuralSpec(from: "Cabinet Hinge")
        XCTAssertNotNil(hingeCase)
        XCTAssertEqual(hingeCase?.type, .hinge)
    }
    
    // MARK: - 3. Kinematic, Motion & Mechanical Specification Parsing
    
    func testMechanicalMotionSpecParsing() {
        let bearingCase = detector.parseMechanicalMotionSpec(from: "608ZZ Ball Bearing")
        XCTAssertNotNil(bearingCase)
        XCTAssertEqual(bearingCase?.type, .bearing)
        
        let beltCase = detector.parseMechanicalMotionSpec(from: "GT2 Timing Belt 6mm")
        XCTAssertNotNil(beltCase)
        XCTAssertEqual(beltCase?.type, .belt)
        
        let pulleyCase = detector.parseMechanicalMotionSpec(from: "20T GT2 Pulley")
        XCTAssertNotNil(pulleyCase)
        XCTAssertEqual(pulleyCase?.type, .gear)
        
        let stepperCase = detector.parseMechanicalMotionSpec(from: "NEMA 17 Stepper Motor")
        XCTAssertNotNil(stepperCase)
        XCTAssertEqual(stepperCase?.type, .motor)
    }
    
    // MARK: - 4. Plumbing & Fluidic Specification Parsing
    
    func testPlumbingSpecParsing() {
        let pipeCase = detector.parsePlumbingSpec(from: "1/2\" PVC Pipe")
        XCTAssertNotNil(pipeCase)
        XCTAssertEqual(pipeCase?.type, .pipe)
        
        let tubeCase = detector.parsePlumbingSpec(from: "Bowden Tube 4mm")
        XCTAssertNotNil(tubeCase)
        XCTAssertEqual(tubeCase?.type, .pipe)
        
        let fittingCase = detector.parsePlumbingSpec(from: "Push-Fit PC4-M10 Fitting")
        XCTAssertNotNil(fittingCase)
        XCTAssertEqual(fittingCase?.type, .connector)
        
        let valveCase = detector.parsePlumbingSpec(from: "Brass Ball Valve")
        XCTAssertNotNil(valveCase)
        XCTAssertEqual(valveCase?.type, .connector)
    }
    
    // MARK: - 5. Assembly Tools & Instruments Specification Parsing
    
    func testToolSpecParsing() {
        let allenCase = detector.parseToolSpec(from: "3mm Allen Key")
        XCTAssertNotNil(allenCase)
        XCTAssertEqual(allenCase?.type, .tool)
        
        let screwDriverCase = detector.parseToolSpec(from: "Phillips Screwdriver PH2")
        XCTAssertNotNil(screwDriverCase)
        XCTAssertEqual(screwDriverCase?.type, .tool)
        
        let wrenchCase = detector.parseToolSpec(from: "10mm Spanner Wrench")
        XCTAssertNotNil(wrenchCase)
        XCTAssertEqual(wrenchCase?.type, .tool)
        
        let caliperCase = detector.parseToolSpec(from: "Digital Calipers")
        XCTAssertNotNil(caliperCase)
        XCTAssertEqual(caliperCase?.type, .tool)
    }
    
    // MARK: - 6. Electrical & Electronic Specification Parsing
    
    func testElectricalSpecParsing() {
        let boardCase = detector.parseElectricalSpec(from: "Arduino Uno")
        XCTAssertNotNil(boardCase)
        XCTAssertEqual(boardCase?.type, .board)
        
        let icCase = detector.parseElectricalSpec(from: "ESP32-WROOM-32")
        XCTAssertNotNil(icCase)
        XCTAssertEqual(icCase?.type, .integratedCircuit)
        
        let resCase = detector.parseElectricalSpec(from: "4.7kΩ Resistor")
        XCTAssertNotNil(resCase)
        XCTAssertEqual(resCase?.type, .resistor)
        XCTAssertEqual(resCase?.value, "4.7kΩ")
        
        let capCase = detector.parseElectricalSpec(from: "100µF Capacitor")
        XCTAssertNotNil(capCase)
        XCTAssertEqual(capCase?.type, .capacitorElectrolytic)
        XCTAssertEqual(capCase?.value, "100µF")
        
        let ledCase = detector.parseElectricalSpec(from: "Red LED Diode")
        XCTAssertNotNil(ledCase)
        XCTAssertEqual(ledCase?.type, .led)
    }
    
    // MARK: - 7. Legacy Resistor, Capacitor & IC Parsers
    
    func testDynamicResistorSpecParsing() {
        let testCases: [(input: String, expectedOhms: Double, expectedFormatted: String)] = [
            ("220", 220.0, "220Ω"),
            ("220Ω", 220.0, "220Ω"),
            ("220 ohm", 220.0, "220Ω"),
            ("10k", 10_000.0, "10kΩ"),
            ("10KΩ", 10_000.0, "10kΩ"),
            ("4.7k", 4_700.0, "4.7kΩ"),
            ("4.7kΩ", 4_700.0, "4.7kΩ"),
            ("1M", 1_000_000.0, "1MΩ"),
            ("100kΩ", 100_000.0, "100kΩ"),
            ("330", 330.0, "330Ω")
        ]
        
        for tc in testCases {
            guard let result = detector.parseResistorSpec(from: tc.input) else {
                XCTFail("Failed to parse resistor spec from '\(tc.input)'")
                continue
            }
            XCTAssertEqual(result.ohms, tc.expectedOhms, accuracy: 0.1, "Mismatch in ohms for '\(tc.input)'")
            XCTAssertEqual(result.formattedOhms, tc.expectedFormatted, "Mismatch in formatted ohms for '\(tc.input)'")
        }
    }
    
    func testDynamicCapacitorSpecParsing() {
        let electrolyticCase = detector.parseCapacitorSpec(from: "100uF")
        XCTAssertNotNil(electrolyticCase)
        XCTAssertEqual(electrolyticCase?.value, "100µF")
        XCTAssertTrue(electrolyticCase?.isElectrolytic ?? false)
        
        let ceramicCase = detector.parseCapacitorSpec(from: "22pF")
        XCTAssertNotNil(ceramicCase)
        XCTAssertEqual(ceramicCase?.value, "22PF")
        XCTAssertFalse(ceramicCase?.isElectrolytic ?? true)
    }
    
    func testDynamicIntegratedCircuitSpecParsing() {
        XCTAssertEqual(detector.parseIntegratedCircuitSpec(from: "NE555"), "NE555")
        XCTAssertEqual(detector.parseIntegratedCircuitSpec(from: "ESP32-WROOM-32"), "ESP32-WROOM-32")
        XCTAssertEqual(detector.parseIntegratedCircuitSpec(from: "ATMEGA328P"), "ATMEGA328P")
        XCTAssertEqual(detector.parseIntegratedCircuitSpec(from: "74HC595"), "74HC595")
    }
    
    // MARK: - 8. Taxonomy Leaf Extraction & Type Inference
    
    func testTaxonomyLeafExtraction() {
        XCTAssertEqual(detector.extractTaxonomyLeaf(from: "root/tools/screwdriver"), "Screwdriver")
        XCTAssertEqual(detector.extractTaxonomyLeaf(from: "furniture/hardware/shelf_support"), "Shelf Support")
        XCTAssertEqual(detector.extractTaxonomyLeaf(from: "mechanical/bearings/ball_bearing"), "Ball Bearing")
        
        let screwType = detector.inferComponentTypeFromTaxonomy(identifier: "tools/fastener", leaf: "Wood Screw")
        XCTAssertEqual(screwType, .screw)
        
        let bearingType = detector.inferComponentTypeFromTaxonomy(identifier: "mechanical/motion", leaf: "Ball Bearing")
        XCTAssertEqual(bearingType, .bearing)
        
        let toolType = detector.inferComponentTypeFromTaxonomy(identifier: "tools/hand_tools", leaf: "Wrench")
        XCTAssertEqual(toolType, .tool)
    }
    
    // MARK: - 9. Bill of Materials (BOM) Dynamic Matching
    
    func testBOMMatchingDynamic() {
        let bom: [ComponentRequirement] = [
            ComponentRequirement(
                name: "NEMA 17 Stepper Motor",
                partId: "part_stepper_nema17",
                quantity: 1,
                isOptional: false
            ),
            ComponentRequirement(
                name: "M4x25 Hex Bolt",
                partId: "part_bolt_m4_25",
                quantity: 4,
                isOptional: false
            ),
            ComponentRequirement(
                name: "1/2\" PVC Pipe",
                partId: "part_pvc_pipe_half",
                quantity: 2,
                isOptional: false
            )
        ]
        
        let matched1 = detector.findMatchingBOM(forText: "NEMA 17", in: bom)
        XCTAssertEqual(matched1?.partId, "part_stepper_nema17")
        
        let matched2 = detector.findMatchingBOM(forText: "bolt_m4_25", in: bom)
        XCTAssertEqual(matched2?.partId, "part_bolt_m4_25")
        
        let matched3 = detector.findMatchingBOM(forText: "PVC Pipe", in: bom)
        XCTAssertEqual(matched3?.partId, "part_pvc_pipe_half")
    }
    
    // MARK: - 10. End-to-End Multi-Domain Detection
    
    func testEndToEndMultiDomainDetection() async {
        let expectedBOM: [ComponentRequirement] = [
            ComponentRequirement(
                name: "2020 Aluminum Extrusion",
                partId: "frame_rail_2020",
                quantity: 4,
                isOptional: false
            ),
            ComponentRequirement(
                name: "M4x20 Hex Bolt",
                partId: "fastener_m4_20",
                quantity: 8,
                isOptional: false
            ),
            ComponentRequirement(
                name: "608ZZ Ball Bearing",
                partId: "mech_bearing_608zz",
                quantity: 2,
                isOptional: false
            )
        ]
        
        let observation = VisualObservation(
            detectedText: [
                RecognizedTextElement(text: "2020 Extrusion", confidence: 0.95, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1)),
                RecognizedTextElement(text: "M4x20 Bolt", confidence: 0.92, boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.1, height: 0.1)),
                RecognizedTextElement(text: "608ZZ Bearing", confidence: 0.88, boundingBox: CGRect(x: 0.6, y: 0.6, width: 0.1, height: 0.1))
            ],
            regions: [],
            sceneClassification: "workshop_workbench",
            timestamp: Date()
        )
        
        let detected = detector.detectComponents(
            in: observation,
            calibration: nil,
            expectedComponents: expectedBOM,
            activeStep: nil
        )
        
        XCTAssertEqual(detected.count, 3)
        
        let rail = detected.first { $0.componentType == .rail }
        XCTAssertNotNil(rail)
        XCTAssertEqual(rail?.partId, "frame_rail_2020")
        XCTAssertEqual(rail?.universalAnchorType, "plane")
        
        let bolt = detected.first { $0.componentType == .bolt }
        XCTAssertNotNil(bolt)
        XCTAssertEqual(bolt?.partId, "fastener_m4_20")
        XCTAssertEqual(bolt?.universalAnchorType, "fastener")
        
        let bearing = detected.first { $0.componentType == .bearing }
        XCTAssertNotNil(bearing)
        XCTAssertEqual(bearing?.partId, "mech_bearing_608zz")
        XCTAssertEqual(bearing?.universalAnchorType, "fastener")
    }
    
    // MARK: - 11. Universal Geometric Fastener & Panel Matching (Zero OCR Text)
    
    func testNonTextGeometricFastenerAndPanelMatching() async {
        let furnitureBOM: [ComponentRequirement] = [
            ComponentRequirement(
                name: "Side Panel",
                partId: "part_side_panel",
                quantity: 2,
                isOptional: false
            ),
            ComponentRequirement(
                name: "Wooden Dowels",
                partId: "part_dowel_8mm",
                quantity: 6,
                isOptional: false
            ),
            ComponentRequirement(
                name: "Cam Lock Discs",
                partId: "part_cam_disc",
                quantity: 4,
                isOptional: false
            )
        ]
        
        // Zero OCR text detected on real wooden furniture
        let observation = VisualObservation(
            detectedText: [],
            regions: [
                // Large planar surface (Panel)
                DetectedRegion(label: "salient_panel", confidence: 0.92, boundingBox: CGRect(x: 0.05, y: 0.05, width: 0.70, height: 0.50)),
                // Slender dowel pin (high aspect ratio)
                DetectedRegion(label: "salient_dowel", confidence: 0.88, boundingBox: CGRect(x: 0.80, y: 0.20, width: 0.03, height: 0.15)),
                // Compact cam lock disc
                DetectedRegion(label: "salient_cam", confidence: 0.85, boundingBox: CGRect(x: 0.80, y: 0.45, width: 0.05, height: 0.05))
            ],
            timestamp: Date()
        )
        
        let detected = detector.detectComponents(
            in: observation,
            calibration: nil,
            expectedComponents: furnitureBOM,
            activeStep: nil
        )
        
        XCTAssertEqual(detected.count, 3)
        
        let panel = detected.first { $0.partId == "part_side_panel" }
        XCTAssertNotNil(panel, "Planar panel must be geometrically matched to BOM side panel")
        
        let dowel = detected.first { $0.partId == "part_dowel_8mm" }
        XCTAssertNotNil(dowel, "Slender dowel pin must be geometrically matched to BOM wooden dowels without OCR text")
        
        let cam = detected.first { $0.partId == "part_cam_disc" }
        XCTAssertNotNil(cam, "Compact cam disc must be geometrically matched to BOM cam lock discs without OCR text")
    }
}
