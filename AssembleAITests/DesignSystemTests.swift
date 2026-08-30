//
//  DesignSystemTests.swift
//  AssembleAITests
//

import XCTest
import SwiftUI
@testable import AssembleAI

@MainActor
final class DesignSystemTests: XCTestCase {
    
    // MARK: - Test 1: Corner Radius Tokens Adhere to Apple Continuous Curvature Standard
    func testCornerRadiusTokens() {
        XCTAssertEqual(AppRadius.xs, 8, "Micro chips should be 8pt")
        XCTAssertEqual(AppRadius.sm, 10, "Small controls and badges should be 10pt")
        XCTAssertEqual(AppRadius.md, 14, "Action buttons and inputs should be 14pt")
        XCTAssertEqual(AppRadius.card, 18, "Standard cards and tiles should be 18pt")
        XCTAssertEqual(AppRadius.lg, 22, "Hero containers should be 22pt")
        XCTAssertEqual(AppRadius.sheet, 28, "Bottom presentation sheets should be 28pt")
    }
    
    // MARK: - Test 2: Spacing Scale Adheres to Apple 8pt Grid Standard
    func testSpacingScale8ptGrid() {
        XCTAssertEqual(AppSpacing.screenEdge, 20, "Screen edge margin must match native Apple 20pt standard")
        XCTAssertEqual(AppSpacing.xxs, 2)
        XCTAssertEqual(AppSpacing.xs, 4)
        XCTAssertEqual(AppSpacing.sm, 8)
        XCTAssertEqual(AppSpacing.mdSm, 12)
        XCTAssertEqual(AppSpacing.md, 16)
        XCTAssertEqual(AppSpacing.mdLg, 20)
        XCTAssertEqual(AppSpacing.lg, 24)
        XCTAssertEqual(AppSpacing.xl, 32)
        XCTAssertEqual(AppSpacing.xxl, 48)
        XCTAssertEqual(AppSpacing.xxxl, 64)
    }
    
    // MARK: - Test 3: Semantic Status Colors
    func testSemanticStatusColors() {
        XCTAssertNotNil(AppColors.statusLive, "Live status color must be defined")
        XCTAssertNotNil(AppColors.statusListening, "Listening status color must be defined")
        XCTAssertNotNil(AppColors.statusSpeaking, "Speaking status color must be defined")
        XCTAssertNotNil(AppColors.statusVerifying, "Verifying status color must be defined")
        XCTAssertNotNil(AppColors.statusPaused, "Paused status color must be defined")
        XCTAssertNotNil(AppColors.statusSuccess, "Success status color must be defined")
        XCTAssertNotNil(AppColors.statusWarning, "Warning status color must be defined")
        XCTAssertNotNil(AppColors.statusError, "Error status color must be defined")
        XCTAssertNotNil(AppColors.cameraControlBackground, "Camera HUD background must be defined")
        XCTAssertNotNil(AppColors.cameraCardBorder, "Camera HUD border must be defined")
    }
    
    // MARK: - Test 4: Elevation Shadows
    func testElevationShadows() {
        XCTAssertNotNil(AppShadow.subtleColor)
        XCTAssertNotNil(AppShadow.mediumColor)
        XCTAssertNotNil(AppShadow.elevatedColor)
    }
    
    // MARK: - Test 5: Reusable Component Initialization
    func testReusableComponentInitialization() {
        let pill = StatusPill(text: "LIVE", status: .live)
        XCTAssertEqual(pill.text, "LIVE")
        XCTAssertEqual(pill.status, .live)
        
        let tile = StatTile(title: "ATTEMPTS", value: "2", icon: "viewfinder")
        XCTAssertEqual(tile.title, "ATTEMPTS")
        XCTAssertEqual(tile.value, "2")
        XCTAssertEqual(tile.icon, "viewfinder")
    }
}
