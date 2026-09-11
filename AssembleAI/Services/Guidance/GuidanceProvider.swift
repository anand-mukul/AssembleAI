//
//  GuidanceProvider.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Protocol for generating visual camera overlay guidance specifications from state comparison outcomes.
protocol GuidanceProviding: Sendable {
    /// Produces a visual `GuidanceOverlay` for camera rendering based on comparison results and target screen bounds.
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize
    ) async -> GuidanceOverlay?
}

/// Abstract extension point protocol for future ARKit / RealityKit 3D spatial guidance providers.
protocol SpatialGuidanceProviding: Sendable {
    /// Extensible method for generating 3D spatial guidance anchors in AR world space.
    func updateSpatialGuidance(
        observation: VisualObservation,
        expectedState: ExpectedAssemblyState
    ) async throws -> GuidanceOverlay
}

/// Default camera overlay guidance provider calculating 2D visual overlay coordinates for camera previews.
nonisolated struct DefaultGuidanceProvider: GuidanceProviding {
    
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize
    ) async -> GuidanceOverlay? {
        switch comparison.status {
        case .correct:
            return GuidanceOverlay(
                title: "Verified",
                message: "Physical setup matches target step contract.",
                style: .success
            )
            
        case .uncertain:
            return GuidanceOverlay(
                title: "Need a clearer view",
                message: "Move closer and ensure the assembly is clearly illuminated inside the frame.",
                style: .warning
            )
            
        case .incorrect:
            if let issue = comparison.issues.first {
                let style: GuidanceStyle = {
                    switch issue.type {
                    case .wrongPosition, .wrongConnection:
                        return .move
                    case .missingComponent:
                        return .target
                    default:
                        return .warning
                    }
                }()
                return GuidanceOverlay(
                    title: issue.title,
                    message: issue.explanation,
                    style: style
                )
            } else {
                return GuidanceOverlay(
                    title: "Adjustment Needed",
                    message: "Physical assembly requires adjustment to match step requirements: \(step.title).",
                    style: .warning
                )
            }
        }
    }
}
