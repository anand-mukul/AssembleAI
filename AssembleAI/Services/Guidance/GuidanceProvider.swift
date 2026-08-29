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
struct DefaultGuidanceProvider: GuidanceProviding {
    
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize
    ) async -> GuidanceOverlay? {
        switch comparison.status {
        case .correct:
            return GuidanceOverlay(
                title: "✓ Verified",
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
            let primaryIssue = comparison.issues.first
            
            if let issue = primaryIssue {
                switch issue.type {
                case .wrongPosition:
                    // Simulated overlay coordinates for demo wrong position (e.g. Row 14 -> Row 15)
                    let sourceRect = CGRect(x: viewSize.width * 0.35, y: viewSize.height * 0.42, width: 90, height: 60)
                    let destRect = CGRect(x: viewSize.width * 0.55, y: viewSize.height * 0.42, width: 90, height: 60)
                    
                    return GuidanceOverlay(
                        title: "Wrong position",
                        message: "Move component lead one slot to the right (Row 15).",
                        sourceRegion: sourceRect,
                        destinationRegion: destRect,
                        style: .move
                    )
                    
                case .wrongConnection:
                    let sourceRect = CGRect(x: viewSize.width * 0.30, y: viewSize.height * 0.38, width: 80, height: 50)
                    let destRect = CGRect(x: viewSize.width * 0.50, y: viewSize.height * 0.52, width: 80, height: 50)
                    
                    return GuidanceOverlay(
                        title: "Wrong connection",
                        message: "Move wire from 5V power rail to GND ground rail.",
                        sourceRegion: sourceRect,
                        destinationRegion: destRect,
                        style: .move
                    )
                    
                case .missingComponent:
                    let targetRect = CGRect(x: viewSize.width * 0.35, y: viewSize.height * 0.40, width: 120, height: 80)
                    
                    return GuidanceOverlay(
                        title: "Target placement",
                        message: "Insert \(step.title) inside highlighted target area.",
                        targetRegion: targetRect,
                        style: .target
                    )
                    
                default:
                    return GuidanceOverlay(
                        title: issue.title,
                        message: issue.explanation,
                        style: .warning
                    )
                }
            } else {
                return GuidanceOverlay(
                    title: "Attention needed",
                    message: "Adjust component alignment to match target blueprint.",
                    style: .warning
                )
            }
        }
    }
}
