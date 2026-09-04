//
//  MockVisionService.swift
//  AssembleAITests
//

import Foundation
import UIKit
import CoreVideo
import CoreMedia
import ImageIO
@testable import AssembleAI

/// Mock computer vision analysis service for unit testing and deterministic simulation.
///
/// Supports predetermined observation sequences, simulated processing latencies, and synthetic detection generation.
nonisolated final class MockVisionService: VisionAnalyzing, @unchecked Sendable {
    private let lock = NSLock()
    private var scriptedObservations: [VisualObservation] = []
    private var simulatedLatencyMs: Double
    private var callCount: Int = 0
    
    var mockObservations: [VisualObservation] {
        get {
            lock.withLock { scriptedObservations }
        }
        set {
            lock.withLock {
                scriptedObservations = newValue
                callCount = 0
            }
        }
    }
    
    nonisolated init(
        scriptedObservations: [VisualObservation] = [],
        simulatedLatencyMs: Double = 50.0
    ) {
        self.scriptedObservations = scriptedObservations
        self.simulatedLatencyMs = simulatedLatencyMs
    }
    
    /// Enqueues a predetermined sequence of observations to be emitted consecutively.
    func setScriptedObservations(_ observations: [VisualObservation]) {
        lock.withLock {
            self.scriptedObservations = observations
            self.callCount = 0
        }
    }
    
    // MARK: - VisionAnalyzing Conformance
    
    func analyze(image: UIImage) async throws -> VisualObservation {
        if simulatedLatencyMs > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedLatencyMs * 1_000_000))
        }
        
        let nextObservation: VisualObservation? = lock.withLock {
            guard !scriptedObservations.isEmpty else { return nil }
            let index = min(callCount, scriptedObservations.count - 1)
            callCount += 1
            return scriptedObservations[index]
        }
        
        if let obs = nextObservation {
            return obs
        }
        
        // Default synthesized observation
        return VisualObservation(
            imageSize: image.size,
            detectedText: [
                DetectedText(text: "220 OHM RESISTOR R1", confidence: 0.94, boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.1))
            ],
            regions: [
                DetectedRegion(label: "Component Slot #1", confidence: 0.88, boundingBox: CGRect(x: 0.2, y: 0.25, width: 0.6, height: 0.2))
            ],
            timestamp: Date(),
            processingTimeMs: simulatedLatencyMs
        )
    }
    
    func analyze(
        frame: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        timestamp: CMTime = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
    ) async throws -> VisualObservation {
        if simulatedLatencyMs > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedLatencyMs * 1_000_000))
        }
        
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        
        let nextObservation: VisualObservation? = lock.withLock {
            guard !scriptedObservations.isEmpty else { return nil }
            let index = min(callCount, scriptedObservations.count - 1)
            callCount += 1
            return scriptedObservations[index]
        }
        
        if let obs = nextObservation {
            return obs
        }
        
        let observationTimestamp: Date
        if CMTIME_IS_VALID(timestamp) && timestamp.timescale > 0 {
            observationTimestamp = Date(timeIntervalSince1970: CMTimeGetSeconds(timestamp))
        } else {
            observationTimestamp = Date()
        }
        
        return VisualObservation(
            imageSize: CGSize(width: width, height: height),
            detectedText: [
                DetectedText(text: "220 OHM RESISTOR R1", confidence: 0.94, boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.1))
            ],
            regions: [
                DetectedRegion(label: "Component Slot #1", confidence: 0.88, boundingBox: CGRect(x: 0.2, y: 0.25, width: 0.6, height: 0.2))
            ],
            timestamp: observationTimestamp,
            processingTimeMs: simulatedLatencyMs
        )
    }
    
    func observationStream(
        from sampledFrames: AsyncStream<SampledFrame>,
        orientation: CGImagePropertyOrientation = .up
    ) -> AsyncStream<VisualObservation> {
        AsyncStream(VisualObservation.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task { [weak self] in
                for await frame in sampledFrames {
                    guard !Task.isCancelled else { break }
                    guard let self = self else { break }
                    
                    if let observation = try? await self.analyze(
                        frame: frame.pixelBuffer,
                        orientation: orientation,
                        timestamp: frame.timestamp
                    ) {
                        continuation.yield(observation)
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
