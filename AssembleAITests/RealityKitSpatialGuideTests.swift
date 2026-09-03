//
//  RealityKitSpatialGuideTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
import simd
@testable import AssembleAI

final class RealityKitSpatialGuideTests: XCTestCase {
    
    private var guideService: RealityKitSpatialGuideService!
    
    override func setUp() {
        super.setUp()
        guideService = RealityKitSpatialGuideService()
    }
    
    override func tearDown() {
        guideService = nil
        super.tearDown()
    }
    
    func testGeneratePinBeaconPrimitiveFromTarget() {
        let overlay = GuidanceOverlay(
            title: "Target",
            message: "Row 10E",
            targetRegion: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            style: .target
        )
        
        let primitives = guideService.generateVolumetricPrimitives(from: overlay)
        
        XCTAssertEqual(primitives.count, 1)
        switch primitives[0] {
        case .pinBeacon(_, let radius, let label):
            XCTAssertEqual(label, "Row 10E")
            XCTAssertGreaterThan(radius, 0.0)
        default:
            XCTFail("Expected .pinBeacon, got \(primitives[0])")
        }
    }
    
    func testGenerateMoveArcPrimitiveFromMove() {
        let overlay = GuidanceOverlay(
            title: "Shift Lead",
            message: "Move to Row 15",
            sourceRegion: CGRect(x: 0.3, y: 0.4, width: 0.1, height: 0.1),
            destinationRegion: CGRect(x: 0.6, y: 0.4, width: 0.1, height: 0.1),
            style: .move
        )
        
        let primitives = guideService.generateVolumetricPrimitives(from: overlay)
        
        XCTAssertEqual(primitives.count, 1)
        switch primitives[0] {
        case .moveArc(let from, let to, let peak, let label):
            XCTAssertEqual(label, "Move to Row 15")
            XCTAssertNotEqual(from, to)
            XCTAssertEqual(peak, 0.04)
        default:
            XCTFail("Expected .moveArc, got \(primitives[0])")
        }
    }
    
    func testGenerateSuccessPrimitive() {
        let overlay = GuidanceOverlay(
            title: "Verified",
            message: "Done",
            style: .success
        )
        
        let primitives = guideService.generateVolumetricPrimitives(from: overlay)
        
        XCTAssertEqual(primitives.count, 1)
        switch primitives[0] {
        case .successConfirmation:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .successConfirmation, got \(primitives[0])")
        }
    }
}
