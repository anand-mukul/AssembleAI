//
//  GuidanceProvider.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Protocol for generating visual camera overlay guidance specifications from state comparison outcomes.
protocol GuidanceProviding: Sendable {
    /// Produces a visual `GuidanceOverlay` for camera rendering based on comparison results, target screen bounds, and observed physical state.
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize,
        observedState: ObservedAssemblyState?
    ) async -> GuidanceOverlay?
}

/// Default protocol extension providing backwards compatibility for callers not passing observed state.
extension GuidanceProviding {
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize
    ) async -> GuidanceOverlay? {
        await guidance(for: comparison, step: step, viewSize: viewSize, observedState: nil)
    }
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
///
/// When `observedState` contains bounding boxes from Vision detections, this provider maps them to real
/// screen-space `CGRect` coordinates so that `SpatialAROverlayView` and `AssemblyGuidanceOverlayView`
/// can render target/move overlays directly over the camera feed.
nonisolated struct DefaultGuidanceProvider: GuidanceProviding {
    
    func guidance(
        for comparison: StateComparison,
        step: AssemblyStep,
        viewSize: CGSize,
        observedState: ObservedAssemblyState?
    ) async -> GuidanceOverlay? {
        switch comparison.status {
        case .correct:
            // Compute center point for success overlay from observed bounding boxes
            let targetRect = primaryDetectionScreenRect(from: observedState, viewSize: viewSize)
            return GuidanceOverlay(
                title: "Verified",
                message: "Physical setup matches target step contract.",
                targetRegion: targetRect,
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
                
                // Compute screen-space coordinates from observed detections
                let screenRects = computeScreenCoordinates(
                    for: issue,
                    observedState: observedState,
                    viewSize: viewSize
                )
                
                return GuidanceOverlay(
                    title: issue.title,
                    message: issue.explanation,
                    targetRegion: screenRects.target,
                    sourceRegion: screenRects.source,
                    destinationRegion: screenRects.destination,
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
    
    // MARK: - Vision-to-Screen Coordinate Mapping
    
    /// Converts a Vision normalized-coordinate `CGRect` (origin bottom-left, Y-up) to
    /// screen-space `CGRect` (origin top-left, Y-down) for SwiftUI overlay rendering.
    private func visionToScreen(_ visionRect: CGRect, viewSize: CGSize) -> CGRect {
        let x = visionRect.origin.x * viewSize.width
        let y = (1.0 - visionRect.origin.y - visionRect.height) * viewSize.height
        let w = visionRect.width * viewSize.width
        let h = visionRect.height * viewSize.height
        return CGRect(x: x, y: y, width: max(w, 60), height: max(h, 40))
    }
    
    /// Extracts the primary detected component's bounding box as a screen-space rect.
    private func primaryDetectionScreenRect(from observedState: ObservedAssemblyState?, viewSize: CGSize) -> CGRect? {
        guard let state = observedState else { return nil }
        
        // Prefer component bounding boxes
        if let comp = state.detectedComponents.first(where: { $0.boundingBox != .zero }) {
            return visionToScreen(comp.boundingBox, viewSize: viewSize)
        }
        // Fallback to position regions
        if let pos = state.detectedPositions.first(where: { $0.region != .zero }) {
            return visionToScreen(pos.region, viewSize: viewSize)
        }
        return nil
    }
    
    /// Computes source/destination/target screen rects for guidance overlay based on issue type.
    private func computeScreenCoordinates(
        for issue: StateIssue,
        observedState: ObservedAssemblyState?,
        viewSize: CGSize
    ) -> (target: CGRect?, source: CGRect?, destination: CGRect?) {
        guard let state = observedState else {
            return (nil, nil, nil)
        }
        
        switch issue.type {
        case .missingComponent:
            // Show a target box where the missing component should be placed.
            // Use the first detected region as a reference anchor if available.
            let targetRect = primaryDetectionScreenRect(from: observedState, viewSize: viewSize)
            ?? centeredTargetRect(viewSize: viewSize)
            return (targetRect, nil, nil)
            
        case .wrongPosition, .wrongConnection:
            // Source = where the component IS (observed bounding box)
            // Destination = where it SHOULD be (offset from source based on issue)
            let sourceRect: CGRect
            if let comp = state.detectedComponents.first(where: { $0.boundingBox != .zero }) {
                sourceRect = visionToScreen(comp.boundingBox, viewSize: viewSize)
            } else if let pos = state.detectedPositions.first(where: { $0.region != .zero }) {
                sourceRect = visionToScreen(pos.region, viewSize: viewSize)
            } else {
                return (nil, nil, nil)
            }
            
            // Destination is estimated as an offset from source (one breadboard pitch ~ 2.54mm visual offset)
            let offsetX: CGFloat = 45.0  // Approximate one breadboard pitch in screen pixels
            let destRect = sourceRect.offsetBy(dx: offsetX, dy: 0)
            
            return (nil, sourceRect, destRect)
            
        default:
            let targetRect = primaryDetectionScreenRect(from: observedState, viewSize: viewSize)
            return (targetRect, nil, nil)
        }
    }
    
    /// Fallback centered target rect when no detection coordinates are available.
    private func centeredTargetRect(viewSize: CGSize) -> CGRect {
        let w: CGFloat = 120
        let h: CGFloat = 80
        return CGRect(
            x: (viewSize.width - w) / 2,
            y: (viewSize.height - h) / 2,
            width: w,
            height: h
        )
    }
}
