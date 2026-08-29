//
//  MockVisionService.swift
//  AssembleAI
//

import Foundation
import UIKit
import CoreVideo
import CoreMedia
import ImageIO

/// Mock computer vision analysis service for unit testing and simulator demonstration mode.
///
/// Supports predetermined observation sequences, simulated processing latencies, and synthetic detection generation.
final class MockVisionService: VisionAnalyzing, @unchecked Sendable {
    private let lock = NSLock()
    private var scriptedObservations: [VisualObservation] = []
    private var simulatedLatencyMs: Double
    private var callCount: Int = 0
    
    init(
        scriptedObservations: [VisualObservation] = [],
        simulatedLatencyMs: Double = 50.0
    ) {
        self.scriptedObservations = scriptedObservations
        self.simulatedLatencyMs = simulatedLatencyMs
    }
    
    /// Enqueues a predetermined sequence of observations to be emitted consecutively.
    func setScriptedObservations(_ observations: [VisualObservation]) {
        lock.lock()
        defer { lock.unlock() }
        self.scriptedObservations = observations
        self.callCount = 0
    }
    
    // MARK: - VisionAnalyzing Conformance
    
    func analyze(image: UIImage) async throws -> VisualObservation {
        if simulatedLatencyMs > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedLatencyMs * 1_000_000))
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        if !scriptedObservations.isEmpty {
            let index = min(callCount, scriptedObservations.count - 1)
            callCount += 1
            return scriptedObservations[index]
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
        
        lock.lock()
        defer { lock.unlock() }
        
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        
        if !scriptedObservations.isEmpty {
            let index = min(callCount, scriptedObservations.count - 1)
            callCount += 1
            return scriptedObservations[index]
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
                for await sampledFrame in sampledFrames {
                    guard !Task.isCancelled else { break }
                    guard let self = self else { break }
                    
                    do {
                        let observation = try await self.analyze(
                            frame: sampledFrame.pixelBuffer,
                            orientation: orientation,
                            timestamp: sampledFrame.timestamp
                        )
                        guard !Task.isCancelled else { break }
                        continuation.yield(observation)
                    } catch is CancellationError {
                        break
                    } catch {
                        let empty = VisualObservation(
                            imageSize: CGSize(
                                width: CVPixelBufferGetWidth(sampledFrame.pixelBuffer),
                                height: CVPixelBufferGetHeight(sampledFrame.pixelBuffer)
                            ),
                            detectedText: [],
                            regions: [],
                            processingTimeMs: 0.0
                        )
                        continuation.yield(empty)
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
