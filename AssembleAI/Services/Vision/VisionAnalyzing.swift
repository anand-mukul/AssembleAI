//
//  VisionAnalyzing.swift
//  AssembleAI
//

import Foundation
import UIKit
import CoreVideo
import CoreMedia
import ImageIO

/// Protocol for analyzing captured camera images and live video pixel buffers using computer vision algorithms.
public protocol VisionAnalyzing: Sendable {
    /// Analyzes a captured UIImage and produces structured visual observations (existing manual capture workflow).
    func analyze(image: UIImage) async throws -> VisualObservation
    
    /// Analyzes a live pixel buffer directly using Apple Vision framework.
    func analyze(
        frame: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        timestamp: CMTime
    ) async throws -> VisualObservation
    
    /// Creates an asynchronous observation stream from a sampled frame stream with bounded concurrency.
    func observationStream(
        from sampledFrames: AsyncStream<SampledFrame>,
        orientation: CGImagePropertyOrientation
    ) -> AsyncStream<VisualObservation>
}

public extension VisionAnalyzing {
    /// Convenience overload analyzing a pixel buffer with default orientation and timestamp.
    func analyze(frame: CVPixelBuffer) async throws -> VisualObservation {
        try await analyze(
            frame: frame,
            orientation: .up,
            timestamp: CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
        )
    }
    
    /// Convenience overload creating an observation stream with default portrait orientation.
    func observationStream(
        from sampledFrames: AsyncStream<SampledFrame>
    ) -> AsyncStream<VisualObservation> {
        observationStream(from: sampledFrames, orientation: .up)
    }
}

