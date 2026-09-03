//
//  UniversalPhysicalAnchorTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class UniversalPhysicalAnchorTests: XCTestCase {
    
    // MARK: - Grid Anchor Tests
    
    func testStandardBreadboardGridAnchor() {
        let grid = GridAnchorDefinition.standardBreadboard
        XCTAssertEqual(grid.pitchMm, 2.54)
        XCTAssertEqual(grid.rows, 30)
        XCTAssertTrue(grid.hasCenterDivider)
        XCTAssertEqual(grid.centerDividerWidthMm, 7.62)
    }
    
    func testLegoGridAnchor() {
        let lego = GridAnchorDefinition.legoPlate
        XCTAssertEqual(lego.pitchMm, 8.0)
        XCTAssertEqual(lego.rows, 16)
        XCTAssertFalse(lego.hasCenterDivider)
    }
    
    // MARK: - Plane Anchor Tests
    
    func testPlaneAnchorPerpendicularJoint() {
        let plane = PlaneAnchorDefinition(
            surfaceId: "side_panel_left",
            description: "Left side shelf joint",
            targetPlaneBounds: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            requiredAngleDegrees: 90.0,
            toleranceDegrees: 3.0
        )
        
        XCTAssertEqual(plane.surfaceId, "side_panel_left")
        XCTAssertEqual(plane.requiredAngleDegrees, 90.0)
        XCTAssertEqual(plane.toleranceDegrees, 3.0)
    }
    
    // MARK: - Fastener Anchor Tests
    
    func testFastenerAnchorCountAndType() {
        let fastener = FastenerAnchorDefinition(
            fastenerType: .screw,
            requiredCount: 4,
            locationDescription: "Corner bracket mounting holes",
            requiresFlushSeating: true
        )
        
        XCTAssertEqual(fastener.fastenerType, .screw)
        XCTAssertEqual(fastener.requiredCount, 4)
        XCTAssertTrue(fastener.requiresFlushSeating)
    }
    
    func testFastenerAnchorDowelType() {
        let dowel = FastenerAnchorDefinition(
            fastenerType: .dowel,
            requiredCount: 6,
            locationDescription: "Shelf alignment holes"
        )
        
        XCTAssertEqual(dowel.fastenerType, .dowel)
        XCTAssertEqual(dowel.requiredCount, 6)
    }
    
    // MARK: - Connector Anchor Tests
    
    func testConnectorAnchorElectricalWire() {
        let conn = ConnectorAnchorDefinition(
            fromNode: "12B",
            toNode: "GND_Rail",
            medium: .electricalWire,
            polaritySensitive: true
        )
        
        XCTAssertEqual(conn.fromNode, "12B")
        XCTAssertEqual(conn.toNode, "GND_Rail")
        XCTAssertEqual(conn.medium, .electricalWire)
        XCTAssertTrue(conn.polaritySensitive)
    }
    
    func testConnectorAnchorRibbonCable() {
        let ribbon = ConnectorAnchorDefinition(
            fromNode: "J1_Display",
            toNode: "J2_Mainboard",
            medium: .ribbonCable,
            polaritySensitive: true
        )
        
        XCTAssertEqual(ribbon.medium, .ribbonCable)
    }
}
