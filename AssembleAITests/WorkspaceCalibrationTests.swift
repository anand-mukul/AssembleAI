//
//  WorkspaceCalibrationTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class WorkspaceCalibrationTests: XCTestCase {
    
    // MARK: - Test 1: Electronics Domain Workspace Map Announcement
    func testElectronicsWorkspaceMapAnnouncement() {
        let map = WorkspaceMap(
            domain: .electronics,
            breadboardDetected: true,
            breadboardVariant: .halfSize,
            breadboardCalibration: nil,
            existingComponents: [],
            lightingQuality: .optimal,
            estimatedWorkingArea: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        )
        
        XCTAssertEqual(map.domain, .electronics)
        XCTAssertTrue(map.summaryAnnouncement.contains("half-size 400-point breadboard"))
        XCTAssertTrue(map.summaryAnnouncement.contains("optimal"))
        XCTAssertTrue(map.summaryAnnouncement.contains("Workspace is clear and ready."))
    }
    
    // MARK: - Test 2: Physical Domain Furniture Workspace Announcement
    func testPhysicalDomainWorkspaceAnnouncement() {
        let dowel = ObservedComponent(identifier: "part_dowel_8mm", name: "Wooden Dowel", confidence: 0.90)
        let panel = ObservedComponent(identifier: "part_side_panel", name: "Side Panel", confidence: 0.95)
        
        let map = WorkspaceMap(
            domain: .physical,
            breadboardDetected: false,
            breadboardVariant: .halfSize,
            breadboardCalibration: nil,
            existingComponents: [dowel, panel],
            lightingQuality: .optimal,
            estimatedWorkingArea: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        )
        
        XCTAssertEqual(map.domain, .physical)
        XCTAssertTrue(map.summaryAnnouncement.contains("assembly workbench"))
        XCTAssertFalse(map.summaryAnnouncement.contains("breadboard"))
        XCTAssertTrue(map.summaryAnnouncement.contains("cataloged 2 components"))
    }
    
    // MARK: - Test 3: Hybrid Aerospace / Engine Workspace Announcement
    func testHybridDomainWorkspaceAnnouncement() {
        let map = WorkspaceMap(
            domain: .hybrid,
            breadboardDetected: false,
            breadboardVariant: .fullSize,
            breadboardCalibration: nil,
            existingComponents: [],
            lightingQuality: .dim,
            estimatedWorkingArea: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        )
        
        XCTAssertEqual(map.domain, .hybrid)
        XCTAssertTrue(map.summaryAnnouncement.contains("integrated workspace"))
        XCTAssertTrue(map.summaryAnnouncement.contains("a bit dim"))
    }
    
    // MARK: - Test 4: Electronics Domain Undetected Breadboard Announcement
    func testElectronicsDomainUndetectedBreadboardAnnouncement() {
        let map = WorkspaceMap(
            domain: .electronics,
            breadboardDetected: false,
            breadboardVariant: .halfSize,
            breadboardCalibration: nil,
            existingComponents: [],
            lightingQuality: .optimal,
            estimatedWorkingArea: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        )
        
        XCTAssertEqual(map.domain, .electronics)
        XCTAssertFalse(map.summaryAnnouncement.contains("400-point breadboard"))
        XCTAssertTrue(map.summaryAnnouncement.contains("Align breadboard within camera view"))
    }
}
