//
//  SpatialVolumetricAnchor.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import simd

/// 3D Spatial Transform representation in metric world space (meters).
nonisolated struct SpatialTransform3D: Sendable, Equatable {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>
    
    init(
        position: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    ) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
    
    static let identity = SpatialTransform3D()
}

/// 3D Volumetric guidance primitives rendered in spatial computing (Apple Vision Pro & ARKit).
nonisolated enum VolumetricGuidancePrimitive: Sendable, Equatable {
    /// 3D pulsing vertical beacon/cylinder anchored to a specific pin or screw hole.
    case pinBeacon(position: SIMD3<Float>, radiusMeters: Float, label: String)
    
    /// 3D parabolic curved vector connecting source placement to destination target.
    case moveArc(from: SIMD3<Float>, to: SIMD3<Float>, peakHeightMeters: Float, label: String)
    
    /// 3D planar bounding frame highlighting a surface boundary or 90° perpendicular joint.
    case planarFrame(origin: SIMD3<Float>, normal: SIMD3<Float>, size: SIMD2<Float>, label: String)
    
    /// 3D success ring / burst confirmation when step verification passes.
    case successConfirmation(position: SIMD3<Float>)
}

/// Math utility projecting 2D camera normalized coordinates into 3D metric camera space.
nonisolated struct SpatialProjectionEngine: Sendable {
    
    /// Projects a 2D normalized camera coordinate [0...1] into 3D metric coordinates at a given working distance.
    ///
    /// - Parameters:
    ///   - point: Normalized coordinate (origin top-left).
    ///   - distanceMeters: Estimated distance to workbench (typically 0.25m to 0.45m for hand assembly).
    ///   - fieldOfViewRadians: Camera horizontal field of view (~60° / 1.05 rad on iPhone standard lens).
    static func projectTo3D(
        normalizedPoint point: CGPoint,
        distanceMeters: Float = 0.35,
        fieldOfViewRadians: Float = 1.05
    ) -> SIMD3<Float> {
        let halfFov = fieldOfViewRadians / 2.0
        let tanHalf = tan(halfFov)
        
        // Centered coordinates [-0.5 ... +0.5]
        let xNorm = Float(point.x - 0.5)
        let yNorm = Float(point.y - 0.5)
        
        // Metric X, Y in camera coordinate space (X right, Y down, Z forward)
        let xMeters = 2.0 * xNorm * distanceMeters * tanHalf
        let yMeters = 2.0 * yNorm * distanceMeters * tanHalf
        let zMeters = distanceMeters
        
        return SIMD3<Float>(xMeters, yMeters, zMeters)
    }
    
    /// Calculates 3D Euclidean distance between two spatial points in millimeters.
    static func distanceMm(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float {
        simd_distance(a, b) * 1000.0
    }
    
    /// Computes midpoint of a 3D parabolic arc between two positions.
    static func arcMidpoint(from start: SIMD3<Float>, to end: SIMD3<Float>, arcElevationMeters: Float = 0.04) -> SIMD3<Float> {
        let mid = (start + end) / 2.0
        // Elevate upward along Y axis (negative Y is up in camera space, or +Y in world space)
        return SIMD3<Float>(mid.x, mid.y - arcElevationMeters, mid.z)
    }
}
