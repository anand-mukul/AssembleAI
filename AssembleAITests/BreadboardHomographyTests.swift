//
//  BreadboardHomographyTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class BreadboardHomographyTests: XCTestCase {
    
    // MARK: - BreadboardGeometry Tests
    
    func testBreadboardGeometryDimensions() {
        let halfSize = BreadboardGeometry(variant: .halfSize)
        XCTAssertEqual(halfSize.totalRows, 30)
        XCTAssertEqual(halfSize.widthMm, 55.0)
        XCTAssertEqual(halfSize.heightMm, 85.0)
        
        let fullSize = BreadboardGeometry(variant: .fullSize)
        XCTAssertEqual(fullSize.totalRows, 63)
        XCTAssertEqual(fullSize.widthMm, 55.0)
        XCTAssertEqual(fullSize.heightMm, 165.0)
    }
    
    func testMillimeterPositionForStandardPins() {
        let geom = BreadboardGeometry(variant: .halfSize)
        
        let pin10E = PinCoordinate(row: "10", column: "E")
        let pos10E = geom.millimeterPosition(for: pin10E)
        XCTAssertNotNil(pos10E)
        
        let pin15F = PinCoordinate(row: "15", column: "F")
        let pos15F = geom.millimeterPosition(for: pin15F)
        XCTAssertNotNil(pos15F)
        
        guard let pos10E = pos10E, let pos15F = pos15F else {
            XCTFail("Positions should not be nil")
            return
        }
        // E should be to the left of the center trough, F to the right
        XCTAssertLessThan(pos10E.x, pos15F.x)
        // Row 15 should be below Row 10 (higher y)
        XCTAssertLessThan(pos10E.y, pos15F.y)
    }
    
    func testNormalizedPositionWithinBounds() {
        let geom = BreadboardGeometry(variant: .halfSize)
        let pins = ["1A", "30J", "15E", "15F", "GND-", "VCC+"]
        
        for pStr in pins {
            guard let pin = PinCoordinate(pinString: pStr) else {
                XCTFail("Failed to parse pin: \(pStr)")
                continue
            }
            if let norm = geom.normalizedPosition(for: pin) {
                XCTAssertGreaterThanOrEqual(norm.x, 0.0)
                XCTAssertLessThanOrEqual(norm.x, 1.0)
                XCTAssertGreaterThanOrEqual(norm.y, 0.0)
                XCTAssertLessThanOrEqual(norm.y, 1.0)
            }
        }
    }
    
    func testNearestPinLookupMatchesKnownPosition() {
        let geom = BreadboardGeometry(variant: .halfSize)
        let targetPin = PinCoordinate(row: "10", column: "E")
        guard let targetPos = geom.millimeterPosition(for: targetPin) else {
            XCTFail("Target position should exist")
            return
        }
        
        // Lookup with exact coordinate
        let result = geom.nearestPin(toMillimeterPoint: targetPos)
        XCTAssertNotNil(result)
        guard let result = result else {
            XCTFail("Result should not be nil")
            return
        }
        XCTAssertEqual(result.pin.row, "10")
        XCTAssertEqual(result.pin.column, "E")
        XCTAssertLessThan(result.distanceMm, 0.1)
    }
    
    func testRowDeltaCalculation() {
        let p14 = PinCoordinate(row: "14", column: "F")
        let p15 = PinCoordinate(row: "15", column: "F")
        
        let delta = BreadboardGeometry.rowDelta(from: p14, to: p15)
        XCTAssertEqual(delta, 1)
        
        let reverseDelta = BreadboardGeometry.rowDelta(from: p15, to: p14)
        XCTAssertEqual(reverseDelta, -1)
    }
    
    func testAlignmentGuidanceGeneration() {
        let p14 = PinCoordinate(row: "14", column: "F")
        let p15 = PinCoordinate(row: "15", column: "F")
        
        let guidance = BreadboardGeometry.alignmentGuidance(detected: p14, expected: p15)
        XCTAssertTrue(guidance.contains("Shift lead 1 slot down to Row 15"))
        
        let correctGuidance = BreadboardGeometry.alignmentGuidance(detected: p15, expected: p15)
        XCTAssertTrue(correctGuidance.contains("Placed correctly"))
    }
    
    // MARK: - HomographyMatrix Tests
    
    func testIdentityHomographyTransform() {
        let id = HomographyMatrix.identity
        let pt = CGPoint(x: 0.35, y: 0.72)
        let transformed = id.transform(pt)
        
        XCTAssertEqual(transformed.x, pt.x, accuracy: 1e-6)
        XCTAssertEqual(transformed.y, pt.y, accuracy: 1e-6)
    }
    
    func testHomographyInversion() {
        // Simple scaling + translation homography
        let h = HomographyMatrix(
            m00: 2.0, m01: 0.0, m02: 0.1,
            m10: 0.0, m11: 3.0, m12: 0.2,
            m20: 0.0, m21: 0.0, m22: 1.0
        )
        guard let hInv = h.inverted() else {
            XCTFail("Matrix should be invertible")
            return
        }
        
        let pt = CGPoint(x: 0.4, y: 0.5)
        let projected = h.transform(pt)
        let restored = hInv.transform(projected)
        
        XCTAssertEqual(restored.x, pt.x, accuracy: 1e-5)
        XCTAssertEqual(restored.y, pt.y, accuracy: 1e-5)
    }
    
    func testHomographyComputeFromFourCorners() {
        // Unit square mapped to scaled rectangular area
        let src = [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 1.0, y: 0.0),
            CGPoint(x: 1.0, y: 1.0),
            CGPoint(x: 0.0, y: 1.0)
        ]
        let dst = [
            CGPoint(x: 0.2, y: 0.1),
            CGPoint(x: 0.8, y: 0.1),
            CGPoint(x: 0.8, y: 0.9),
            CGPoint(x: 0.2, y: 0.9)
        ]
        
        guard let H = HomographyMatrix.compute(from: src, to: dst) else {
            XCTFail("Should compute homography")
            return
        }
        
        for i in 0..<4 {
            let mapped = H.transform(src[i])
            XCTAssertEqual(mapped.x, dst[i].x, accuracy: 1e-3)
            XCTAssertEqual(mapped.y, dst[i].y, accuracy: 1e-3)
        }
    }
    
    // MARK: - BreadboardHomographyService Tests
    
    func testProjectPinToCameraAndBack() {
        let service = BreadboardHomographyService()
        let calibration = BreadboardCalibration.defaultCentered()
        
        let pin = PinCoordinate(row: "10", column: "E")
        guard let cameraPoint = service.projectPinToCamera(pin: pin, calibration: calibration) else {
            XCTFail("Pin projection should succeed")
            return
        }
        
        // Point should be within normalized camera viewport [0...1]
        XCTAssertGreaterThan(cameraPoint.x, 0.0)
        XCTAssertLessThan(cameraPoint.x, 1.0)
        XCTAssertGreaterThan(cameraPoint.y, 0.0)
        XCTAssertLessThan(cameraPoint.y, 1.0)
        
        // Map back to nearest pin
        let reversePin = service.mapCameraPointToPin(cameraPoint: cameraPoint, calibration: calibration)
        XCTAssertNotNil(reversePin)
        XCTAssertEqual(reversePin?.pin.row, "10")
        XCTAssertEqual(reversePin?.pin.column, "E")
    }
    
    func testProjectPinPlacementRegion() {
        let service = BreadboardHomographyService()
        let calibration = BreadboardCalibration.defaultCentered()
        
        let from = PinCoordinate(row: "10", column: "E")
        let to = PinCoordinate(row: "15", column: "F")
        
        guard let region = service.projectPinPlacementRegion(from: from, to: to, calibration: calibration) else {
            XCTFail("Should project placement region")
            return
        }
        
        XCTAssertGreaterThan(region.width, 0.0)
        XCTAssertGreaterThan(region.height, 0.0)
        XCTAssertLessThanOrEqual(region.maxX, 1.0)
        XCTAssertLessThanOrEqual(region.maxY, 1.0)
    }
}
