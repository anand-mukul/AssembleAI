//
//  HandPoseActivityDetector.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import Vision
import CoreVideo

/// Temporal user hand activity state relative to the active assembly target.
nonisolated enum WorkbenchHandActivity: String, Sendable, Equatable {
    /// Hands are actively manipulating components inside the target region (tutor remains quiet).
    case handsWorking
    /// Hands have just cleared or retreated from the target area (ideal inspection & verification window).
    case handsRetreated
    /// No hands detected in the frame (clear view of the workpiece).
    case clear
}

/// Diagnostic metrics for workbench hand activity tracking.
nonisolated struct HandActivityObservation: Sendable, Equatable {
    let activity: WorkbenchHandActivity
    let detectedHandsCount: Int
    let handBoundingBoxes: [CGRect]
    let isTargetOccluded: Bool
    let timestamp: Date
}

/// Protocol for detecting workbench hand poses and occlusion states over active target regions.
protocol HandPoseActivityDetecting: Sendable {
    /// Evaluates hand pose in a pixel buffer relative to an optional target assembly region.
    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        targetRegion: CGRect?
    ) async -> HandActivityObservation
}

/// Production implementation using Apple Vision `VNDetectHumanHandPoseRequest`.
nonisolated final class HandPoseActivityDetector: HandPoseActivityDetecting, @unchecked Sendable {
    
    private var lastWasWorking: Bool = false
    private var lastStateChangeTime: Double = 0.0
    
    nonisolated init() {}
    
    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        targetRegion: CGRect? = nil
    ) async -> HandActivityObservation {
        await withCheckedContinuation { continuation in
            let request = VNDetectHumanHandPoseRequest { [weak self] req, error in
                guard let self = self, error == nil,
                      let observations = req.results as? [VNHumanHandPoseObservation],
                      !observations.isEmpty else {
                    let activity: WorkbenchHandActivity = (self?.lastWasWorking == true) ? .handsRetreated : .clear
                    if self?.lastWasWorking == true {
                        self?.lastWasWorking = false
                    }
                    continuation.resume(
                        returning: HandActivityObservation(
                            activity: activity,
                            detectedHandsCount: 0,
                            handBoundingBoxes: [],
                            isTargetOccluded: false,
                            timestamp: Date()
                        )
                    )
                    return
                }
                
                var handBoxes: [CGRect] = []
                var isOccluding = false
                let target = targetRegion ?? CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
                
                for obs in observations {
                    // Extract recognized landmark points (wrist, index tip, thumb tip, etc.)
                    if let points = try? obs.recognizedPoints(.all) {
                        var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0
                        var hasPoints = false
                        
                        for (_, pt) in points where pt.confidence > 0.3 {
                            hasPoints = true
                            // Convert Vision (bottom-left origin) to camera standard (top-left origin)
                            let px = pt.location.x
                            let py = 1.0 - pt.location.y
                            minX = min(minX, px)
                            minY = min(minY, py)
                            maxX = max(maxX, px)
                            maxY = max(maxY, py)
                        }
                        
                        if hasPoints {
                            let box = CGRect(x: minX, y: minY, width: max(0.05, maxX - minX), height: max(0.05, maxY - minY))
                            handBoxes.append(box)
                            if box.intersects(target) {
                                isOccluding = true
                            }
                        }
                    }
                }
                
                let activity: WorkbenchHandActivity
                if isOccluding {
                    activity = .handsWorking
                    self.lastWasWorking = true
                } else if self.lastWasWorking {
                    activity = .handsRetreated
                    self.lastWasWorking = false
                } else {
                    activity = .clear
                }
                
                continuation.resume(
                    returning: HandActivityObservation(
                        activity: activity,
                        detectedHandsCount: observations.count,
                        handBoundingBoxes: handBoxes,
                        isTargetOccluded: isOccluding,
                        timestamp: Date()
                    )
                )
            }
            
            request.maximumHandCount = 2
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(
                    returning: HandActivityObservation(
                        activity: .clear,
                        detectedHandsCount: 0,
                        handBoundingBoxes: [],
                        isTargetOccluded: false,
                        timestamp: Date()
                    )
                )
            }
        }
    }
}
