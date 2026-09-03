//
//  RealityKitSpatialGuideService.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import simd

#if canImport(RealityKit)
import RealityKit
#endif

/// Spatial guidance service generating 3D volumetric guides and RealityKit entity specifications.
///
/// Implements `SpatialGuidanceProviding` to project guidance into visionOS spatial computing volumes
/// or ARKit camera viewports.
final class RealityKitSpatialGuideService: SpatialGuidanceProviding, @unchecked Sendable {
    
    private let homographyService: BreadboardHomographyService
    
    init(homographyService: BreadboardHomographyService = BreadboardHomographyService()) {
        self.homographyService = homographyService
    }
    
    // MARK: - SpatialGuidanceProviding
    
    func updateSpatialGuidance(
        observation: VisualObservation,
        expectedState: ExpectedAssemblyState
    ) async throws -> GuidanceOverlay {
        // Default target region
        let targetRect = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        
        // If expected state has required positions, build volumetric anchors
        if let primaryPosition = expectedState.requiredPositions.first {
            let label = primaryPosition.targetDescription
            return GuidanceOverlay(
                title: "Target Position",
                message: label,
                targetRegion: primaryPosition.region.isEmpty ? targetRect : primaryPosition.region,
                style: .target
            )
        }
        
        return GuidanceOverlay(
            title: "Inspecting Setup",
            message: "Keep workpiece visible in spatial viewfinder.",
            style: .target
        )
    }
    
    // MARK: - 3D Volumetric Primitive Generation
    
    /// Generates 3D volumetric primitives from 2D visual overlay coordinates.
    func generateVolumetricPrimitives(
        from overlay: GuidanceOverlay,
        workbenchDistanceMeters: Float = 0.35
    ) -> [VolumetricGuidancePrimitive] {
        var primitives: [VolumetricGuidancePrimitive] = []
        
        switch overlay.style {
        case .target:
            if let targetBox = overlay.targetRegion {
                let centerPoint = CGPoint(x: targetBox.midX, y: targetBox.midY)
                let pos3D = SpatialProjectionEngine.projectTo3D(
                    normalizedPoint: centerPoint,
                    distanceMeters: workbenchDistanceMeters
                )
                let radius = Float(max(targetBox.width, targetBox.height)) * workbenchDistanceMeters * 0.5
                primitives.append(
                    .pinBeacon(position: pos3D, radiusMeters: max(0.015, radius), label: overlay.message)
                )
            }
            
        case .move:
            if let src = overlay.sourceRegion, let dst = overlay.destinationRegion {
                let srcCenter = CGPoint(x: src.midX, y: src.midY)
                let dstCenter = CGPoint(x: dst.midX, y: dst.midY)
                let startPos = SpatialProjectionEngine.projectTo3D(
                    normalizedPoint: srcCenter,
                    distanceMeters: workbenchDistanceMeters
                )
                let endPos = SpatialProjectionEngine.projectTo3D(
                    normalizedPoint: dstCenter,
                    distanceMeters: workbenchDistanceMeters
                )
                primitives.append(
                    .moveArc(from: startPos, to: endPos, peakHeightMeters: 0.04, label: overlay.message)
                )
            }
            
        case .success:
            let centerPos = SpatialProjectionEngine.projectTo3D(
                normalizedPoint: CGPoint(x: 0.5, y: 0.5),
                distanceMeters: workbenchDistanceMeters
            )
            primitives.append(.successConfirmation(position: centerPos))
            
        case .warning:
            break
        }
        
        return primitives
    }
    
    // MARK: - RealityKit Entity Creation (visionOS / iOS 17+)
    
    #if canImport(RealityKit)
    @MainActor
    func createRealityKitEntities(for primitives: [VolumetricGuidancePrimitive]) -> [Entity] {
        var entities: [Entity] = []
        
        for primitive in primitives {
            switch primitive {
            case .pinBeacon(let position, let radius, _):
                let mesh = MeshResource.generateCylinder(height: 0.02, radius: radius)
                let material = SimpleMaterial(color: .systemCyan, isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.position = position
                entities.append(model)
                
            case .moveArc(let from, let to, _, _):
                // Midpoint marker with arrow cylinder
                let midPos = SpatialProjectionEngine.arcMidpoint(from: from, to: to)
                let mesh = MeshResource.generateSphere(radius: 0.008)
                let material = SimpleMaterial(color: .systemOrange, isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.position = midPos
                entities.append(model)
                
            case .planarFrame(let origin, _, let size, _):
                let mesh = MeshResource.generatePlane(width: size.x, depth: size.y)
                let material = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.3), isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.position = origin
                entities.append(model)
                
            case .successConfirmation(let position):
                let mesh = MeshResource.generateCylinder(height: 0.005, radius: 0.05)
                let material = SimpleMaterial(color: .systemGreen, isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.position = position
                entities.append(model)
            }
        }
        
        return entities
    }
    #endif
}
