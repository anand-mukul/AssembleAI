//
//  SpatialVolumetricAnchorTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
import simd
@testable import AssembleAI

final class SpatialVolumetricAnchorTests: XCTestCase {
    
    func testProjectionTo3DCenterPoint() {
        let center = CGPoint(x: 0.5, y: 0.5)
        let pos3D = SpatialProjectionEngine.projectTo3D(normalizedPoint: center, distanceMeters: 0.40)
        
        // Center point should have (X ≈ 0, Y ≈ 0, Z = 0.40)
        XCTAssertEqual(pos3D.x, 0.0, accuracy: 1e-4)
        XCTAssertEqual(pos3D.y, 0.0, accuracy: 1e-4)
        XCTAssertEqual(pos3D.z, 0.40, accuracy: 1e-4)
    }
    
    func testProjectionTo3DOffsets() {
        let rightPoint = CGPoint(x: 0.8, y: 0.5)
        let leftPoint = CGPoint(x: 0.2, y: 0.5)
        
        let posRight = SpatialProjectionEngine.projectTo3D(normalizedPoint: rightPoint, distanceMeters: 0.35)
        let posLeft = SpatialProjectionEngine.projectTo3D(normalizedPoint: leftPoint, distanceMeters: 0.35)
        
        XCTAssertGreaterThan(posRight.x, 0.0)
        XCTAssertLessThan(posLeft.x, 0.0)
        XCTAssertEqual(abs(posRight.x), abs(posLeft.x), accuracy: 1e-4)
    }
    
    func testDistanceCalculationMm() {
        let p1 = SIMD3<Float>(0.0, 0.0, 0.35)
        let p2 = SIMD3<Float>(0.0254, 0.0, 0.35) // 25.4mm away
        
        let dist = SpatialProjectionEngine.distanceMm(from: p1, to: p2)
        XCTAssertEqual(dist, 25.4, accuracy: 0.1)
    }
    
    func testArcMidpointElevation() {
        let start = SIMD3<Float>(0.1, 0.0, 0.35)
        let end = SIMD3<Float>(0.2, 0.0, 0.35)
        
        let mid = SpatialProjectionEngine.arcMidpoint(from: start, to: end, arcElevationMeters: 0.05)
        
        XCTAssertEqual(mid.x, 0.15, accuracy: 1e-4)
        XCTAssertEqual(mid.y, -0.05, accuracy: 1e-4) // Elevated
        XCTAssertEqual(mid.z, 0.35, accuracy: 1e-4)
    }
}
