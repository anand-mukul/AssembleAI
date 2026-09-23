//
//  MockLiDARSpatialMeshCoordinator.swift
//  AssembleAITests
//
//  Simulator-safe mock for LiDARSpatialMeshCoordinator.
//  Returns deterministic depth/3D data without requiring physical LiDAR hardware.
//

import Foundation
import CoreVideo
import simd
@testable import AssembleAI

/// Scriptable mock actor for LiDARSpatialMeshCoordinator.
/// Lets tests run in Xcode Simulator without iPhone Pro LiDAR hardware.
actor MockLiDARSpatialMeshCoordinator: LiDARSpatialMeshCoordinating {

    // MARK: - State

    var isLiDARSupported: Bool
    private(set) var assessDepthCallCount: Int = 0
    private(set) var unprojectCallCount: Int = 0

    /// Fixed 3D point returned by `unprojectTo3D`. nil simulates occluded / invalid depth.
    var stubbedPoint: Spatial3DPoint? = Spatial3DPoint(
        x: 0.0,
        y: 0.0,
        z: 0.40,
        confidence: 0.95
    )

    /// Fixed mesh assessment returned by `assessDepth`.
    var stubbedAssessment: SpatialMeshAssessment = SpatialMeshAssessment(
        isLiDARAvailable: true,
        surfacePlaneNormal: SIMD3<Float>(0, 1, 0),
        estimatedWorkpieceDimensionsMm: SIMD3<Float>(200, 100, 20),
        detectedMeshAnchorCount: 2,
        nearestDepthMeters: 0.35,
        averageDepthMeters: 0.40
    )

    // MARK: - Init

    init(lidarSupported: Bool = true) {
        self.isLiDARSupported = lidarSupported
    }

    // MARK: - LiDARSpatialMeshCoordinating

    func assessDepth(in depthBuffer: CVPixelBuffer) -> SpatialMeshAssessment {
        assessDepthCallCount += 1
        return stubbedAssessment
    }

    func unprojectTo3D(
        normalizedPoint: CGPoint,
        depthBuffer: CVPixelBuffer
    ) -> Spatial3DPoint? {
        unprojectCallCount += 1
        return stubbedPoint
    }
}
