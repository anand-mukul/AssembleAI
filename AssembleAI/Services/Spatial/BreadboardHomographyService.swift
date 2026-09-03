//
//  BreadboardHomographyService.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import Vision
import CoreVideo
import ImageIO

/// A 3x3 planar projective transformation (homography) matrix.
nonisolated struct HomographyMatrix: Sendable, Equatable {
    // Row-major elements:
    // [ m00, m01, m02 ]
    // [ m10, m11, m12 ]
    // [ m20, m21, m22 ]
    let m00: Double, m01: Double, m02: Double
    let m10: Double, m11: Double, m12: Double
    let m20: Double, m21: Double, m22: Double
    
    static let identity = HomographyMatrix(
        m00: 1, m01: 0, m02: 0,
        m10: 0, m11: 1, m12: 0,
        m20: 0, m21: 0, m22: 1
    )
    
    /// Projects a 2D point using this homography matrix.
    func transform(_ point: CGPoint) -> CGPoint {
        let x = Double(point.x)
        let y = Double(point.y)
        let w = m20 * x + m21 * y + m22
        guard abs(w) > 1e-9 else { return point }
        let px = (m00 * x + m01 * y + m02) / w
        let py = (m10 * x + m11 * y + m12) / w
        return CGPoint(x: px, y: py)
    }
    
    /// Computes the inverse homography matrix using standard 3x3 adjoint matrix inversion.
    func inverted() -> HomographyMatrix? {
        let det = m00 * (m11 * m22 - m12 * m21) -
                  m01 * (m10 * m22 - m12 * m20) +
                  m02 * (m10 * m21 - m11 * m20)
        
        guard abs(det) > 1e-9 else { return nil }
        let invDet = 1.0 / det
        
        let i00 = (m11 * m22 - m12 * m21) * invDet
        let i01 = (m02 * m21 - m01 * m22) * invDet
        let i02 = (m01 * m12 - m02 * m11) * invDet
        
        let i10 = (m12 * m20 - m10 * m22) * invDet
        let i11 = (m00 * m22 - m02 * m20) * invDet
        let i12 = (m02 * m10 - m00 * m12) * invDet
        
        let i20 = (m10 * m21 - m11 * m20) * invDet
        let i21 = (m01 * m20 - m00 * m21) * invDet
        let i22 = (m00 * m11 - m01 * m10) * invDet
        
        return HomographyMatrix(
            m00: i00, m01: i01, m02: i02,
            m10: i10, m11: i11, m12: i12,
            m20: i20, m21: i21, m22: i22
        )
    }
    
    /// Computes the 3x3 homography matrix mapping 4 source points to 4 destination points.
    /// Uses Gaussian elimination with partial pivoting on the standard 8x8 direct linear transform system.
    static func compute(from src: [CGPoint], to dst: [CGPoint]) -> HomographyMatrix? {
        guard src.count == 4, dst.count == 4 else { return nil }
        
        // Build 8x8 system A * h = b (fixing h22 = 1)
        var a = Array(repeating: Array(repeating: 0.0, count: 8), count: 8)
        var b = Array(repeating: 0.0, count: 8)
        
        for i in 0..<4 {
            let xs = Double(src[i].x)
            let ys = Double(src[i].y)
            let xd = Double(dst[i].x)
            let yd = Double(dst[i].y)
            
            // Equation 1: h00*xs + h01*ys + h02 - h20*xs*xd - h21*ys*xd = xd
            a[2 * i][0] = xs
            a[2 * i][1] = ys
            a[2 * i][2] = 1.0
            a[2 * i][3] = 0.0
            a[2 * i][4] = 0.0
            a[2 * i][5] = 0.0
            a[2 * i][6] = -xs * xd
            a[2 * i][7] = -ys * xd
            b[2 * i] = xd
            
            // Equation 2: h10*xs + h11*ys + h12 - h20*xs*yd - h21*ys*yd = yd
            a[2 * i + 1][0] = 0.0
            a[2 * i + 1][1] = 0.0
            a[2 * i + 1][2] = 0.0
            a[2 * i + 1][3] = xs
            a[2 * i + 1][4] = ys
            a[2 * i + 1][5] = 1.0
            a[2 * i + 1][6] = -xs * yd
            a[2 * i + 1][7] = -ys * yd
            b[2 * i + 1] = yd
        }
        
        guard let h = solveLinearSystem8x8(matrix: a, vector: b) else {
            return nil
        }
        
        return HomographyMatrix(
            m00: h[0], m01: h[1], m02: h[2],
            m10: h[3], m11: h[4], m12: h[5],
            m20: h[6], m21: h[7], m22: 1.0
        )
    }
    
    // Gaussian elimination solver for 8x8 system
    private static func solveLinearSystem8x8(matrix: [[Double]], vector: [Double]) -> [Double]? {
        var m = matrix
        var v = vector
        let n = 8
        
        for i in 0..<n {
            // Find pivot
            var maxRow = i
            var maxVal = abs(m[i][i])
            for k in (i + 1)..<n {
                if abs(m[k][i]) > maxVal {
                    maxVal = abs(m[k][i])
                    maxRow = k
                }
            }
            guard maxVal > 1e-9 else { return nil }
            
            // Swap rows
            if maxRow != i {
                m.swapAt(i, maxRow)
                v.swapAt(i, maxRow)
            }
            
            // Eliminate below
            for k in (i + 1)..<n {
                let factor = m[k][i] / m[i][i]
                for j in i..<n {
                    m[k][j] -= factor * m[i][j]
                }
                v[k] -= factor * v[i]
            }
        }
        
        // Back substitution
        var x = Array(repeating: 0.0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = v[i]
            for j in (i + 1)..<n {
                sum -= m[i][j] * x[j]
            }
            x[i] = sum / m[i][i]
        }
        
        return x
    }
}

// MARK: - Breadboard Homography Calibration & Service

/// Detected or calibrated pose of a physical breadboard in normalized camera coordinates.
nonisolated struct BreadboardCalibration: Sendable, Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
    let confidence: Double
    let geometry: BreadboardGeometry
    
    /// Homography mapping camera space [0...1] -> rectified canonical space [0...1]
    let cameraToRectified: HomographyMatrix
    
    /// Inverse homography mapping rectified canonical space [0...1] -> camera space [0...1]
    let rectifiedToCamera: HomographyMatrix
    
    init?(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint,
        confidence: Double = 1.0,
        geometry: BreadboardGeometry = BreadboardGeometry()
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
        self.confidence = confidence
        self.geometry = geometry
        
        let srcPoints = [topLeft, topRight, bottomRight, bottomLeft]
        let canonicalDst = [
            CGPoint(x: 0.0, y: 0.0), // Top-Left
            CGPoint(x: 1.0, y: 0.0), // Top-Right
            CGPoint(x: 1.0, y: 1.0), // Bottom-Right
            CGPoint(x: 0.0, y: 1.0)  // Bottom-Left
        ]
        
        guard let H = HomographyMatrix.compute(from: srcPoints, to: canonicalDst),
              let HInv = H.inverted() else {
            return nil
        }
        
        self.cameraToRectified = H
        self.rectifiedToCamera = HInv
    }
    
    /// Default centered calibration for unoccluded bench views when detection is initializing.
    static func defaultCentered(geometry: BreadboardGeometry = BreadboardGeometry()) -> BreadboardCalibration {
        BreadboardCalibration(
            topLeft: CGPoint(x: 0.20, y: 0.15),
            topRight: CGPoint(x: 0.80, y: 0.15),
            bottomRight: CGPoint(x: 0.80, y: 0.85),
            bottomLeft: CGPoint(x: 0.20, y: 0.85),
            confidence: 0.50,
            geometry: geometry
        )!
    }
}

/// Service protocol for detecting breadboard planar pose and projecting pin coordinates.
protocol BreadboardHomographyServicing: Sendable {
    /// Detects breadboard boundary and computes homography matrix from camera image observations.
    func detectCalibration(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) async -> BreadboardCalibration?
    
    /// Projects a logical `PinCoordinate` to normalized camera coordinates [0...1].
    func projectPinToCamera(pin: PinCoordinate, calibration: BreadboardCalibration) -> CGPoint?
    
    /// Projects a camera view coordinate back to the closest breadboard pin with millimeter distance.
    func mapCameraPointToPin(cameraPoint: CGPoint, calibration: BreadboardCalibration) -> (pin: PinCoordinate, distanceMm: Double)?
    
    /// Projects a pin placement (fromPin -> toPin) to a camera space bounding box with tolerance padding.
    func projectPinPlacementRegion(from: PinCoordinate, to: PinCoordinate, calibration: BreadboardCalibration) -> CGRect?
}

/// Production implementation of breadboard planar homography detection and coordinate transformation.
final class BreadboardHomographyService: BreadboardHomographyServicing {
    
    private let geometry: BreadboardGeometry
    
    init(geometry: BreadboardGeometry = BreadboardGeometry()) {
        self.geometry = geometry
    }
    
    // MARK: - Planar Detection via Apple Vision
    
    func detectCalibration(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) async -> BreadboardCalibration? {
        await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { [weak self] req, error in
                guard let self = self, error == nil,
                      let observations = req.results as? [VNRectangleObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Select most rectangular, portrait-oriented candidate consistent with breadboard aspect ratio (~1.5:1)
                let bestMatch = observations.max(by: { a, b in
                    let aspectA = a.boundingBox.height / max(0.01, a.boundingBox.width)
                    let aspectB = b.boundingBox.height / max(0.01, b.boundingBox.width)
                    let scoreA = a.confidence * Float(aspectA > 1.1 && aspectA < 2.2 ? 1.5 : 0.8)
                    let scoreB = b.confidence * Float(aspectB > 1.1 && aspectB < 2.2 ? 1.5 : 0.8)
                    return scoreA < scoreB
                })
                
                guard let rect = bestMatch else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Note: VNRectangleObservation uses Vision coordinates (origin bottom-left).
                // Convert to UIKit / Camera standard coordinates (origin top-left): y -> 1 - y
                let tl = CGPoint(x: rect.topLeft.x, y: 1.0 - rect.topLeft.y)
                let tr = CGPoint(x: rect.topRight.x, y: 1.0 - rect.topRight.y)
                let br = CGPoint(x: rect.bottomRight.x, y: 1.0 - rect.bottomRight.y)
                let bl = CGPoint(x: rect.bottomLeft.x, y: 1.0 - rect.bottomLeft.y)
                
                let calibration = BreadboardCalibration(
                    topLeft: tl,
                    topRight: tr,
                    bottomRight: br,
                    bottomLeft: bl,
                    confidence: Double(rect.confidence),
                    geometry: self.geometry
                )
                
                continuation.resume(returning: calibration)
            }
            
            request.minimumAspectRatio = 0.4
            request.maximumAspectRatio = 2.5
            request.minimumSize = 0.20
            request.maximumObservations = 4
            request.minimumConfidence = 0.35
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Coordinate Transformations
    
    func projectPinToCamera(pin: PinCoordinate, calibration: BreadboardCalibration) -> CGPoint? {
        guard let canonicalPos = calibration.geometry.normalizedPosition(for: pin) else {
            return nil
        }
        return calibration.rectifiedToCamera.transform(canonicalPos)
    }
    
    func mapCameraPointToPin(cameraPoint: CGPoint, calibration: BreadboardCalibration) -> (pin: PinCoordinate, distanceMm: Double)? {
        let rectifiedPoint = calibration.cameraToRectified.transform(cameraPoint)
        return calibration.geometry.nearestPin(toNormalizedPoint: rectifiedPoint)
    }
    
    func projectPinPlacementRegion(from: PinCoordinate, to: PinCoordinate, calibration: BreadboardCalibration) -> CGRect? {
        guard let p1 = projectPinToCamera(pin: from, calibration: calibration),
              let p2 = projectPinToCamera(pin: to, calibration: calibration) else {
            return nil
        }
        
        let minX = min(p1.x, p2.x)
        let maxX = max(p1.x, p2.x)
        let minY = min(p1.y, p2.y)
        let maxY = max(p1.y, p2.y)
        
        // Add 2% padding around the bounding target
        let padX = max(0.02, (maxX - minX) * 0.2)
        let padY = max(0.02, (maxY - minY) * 0.2)
        
        return CGRect(
            x: max(0.0, minX - padX),
            y: max(0.0, minY - padY),
            width: min(1.0 - minX + padX, (maxX - minX) + 2 * padX),
            height: min(1.0 - minY + padY, (maxY - minY) + 2 * padY)
        )
    }
}
