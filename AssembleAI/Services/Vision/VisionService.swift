//
//  VisionService.swift
//  AssembleAI
//

import Foundation
import Vision
import UIKit
import CoreVideo
import CoreMedia
import ImageIO

/// Diagnostic performance metrics for Vision processing validation.
struct VisionServiceMetrics: Sendable, Equatable {
    var requestsStarted: UInt64 = 0
    var requestsCompleted: UInt64 = 0
    var requestsCancelled: UInt64 = 0
    var averageLatencyMs: Double = 0.0
    var lastObservationTimestamp: Date? = nil
}

/// Concrete computer vision analysis service using Apple's Vision framework (VNRecognizeTextRequest + VNDetectRectanglesRequest).
///
/// Supports both single-image snapshot analysis and continuous CVPixelBuffer streaming with bounded concurrency.
actor VisionService: VisionAnalyzing {
    private let imageProcessor = ImageProcessingService()
    private var metrics = VisionServiceMetrics()
    private var totalLatencyAccumulatorMs: Double = 0.0
    
    init() {}
    
    // MARK: - Manual Image Analysis (Existing Workflow)
    
    /// Analyzes a captured `UIImage` and produces structured visual observations.
    func analyze(image: UIImage) async throws -> VisualObservation {
        metrics.requestsStarted += 1
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try Task.checkCancellation()
        
        // Preprocess image (fix orientation and optimize resolution)
        let preparedImage = imageProcessor.prepareImageForVision(image)
        
        guard let cgImage = preparedImage.cgImage else {
            metrics.requestsCancelled += 1
            throw NSError(domain: "VisionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image format"])
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let (texts, regions) = try await performVisionRequests(on: cgImage)
        
        try Task.checkCancellation()
        
        let elapsedTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        recordMetrics(latencyMs: elapsedTimeMs)
        
        return VisualObservation(
            imageSize: imageSize,
            detectedText: texts,
            regions: regions,
            timestamp: Date(),
            processingTimeMs: elapsedTimeMs
        )
    }
    
    // MARK: - Live PixelBuffer Analysis (Live Tutor Pipeline)
    
    /// Analyzes a live `CVPixelBuffer` directly without converting to `UIImage` or copying memory.
    func analyze(
        frame: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        timestamp: CMTime = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
    ) async throws -> VisualObservation {
        metrics.requestsStarted += 1
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try Task.checkCancellation()
        
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        
        guard width > 0, height > 0 else {
            metrics.requestsCancelled += 1
            throw NSError(domain: "VisionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid pixel buffer dimensions"])
        }
        
        let imageSize = CGSize(width: width, height: height)
        let (texts, regions) = try await performVisionRequests(on: frame, orientation: orientation)
        
        try Task.checkCancellation()
        
        let elapsedTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        recordMetrics(latencyMs: elapsedTimeMs)
        
        let observationTimestamp: Date
        if CMTIME_IS_VALID(timestamp) && timestamp.timescale > 0 {
            observationTimestamp = Date(timeIntervalSince1970: CMTimeGetSeconds(timestamp))
        } else {
            observationTimestamp = Date()
        }
        
        return VisualObservation(
            imageSize: imageSize,
            detectedText: texts,
            regions: regions,
            timestamp: observationTimestamp,
            processingTimeMs: elapsedTimeMs
        )
    }
    
    // MARK: - Live Observation Stream
    
    /// Creates an asynchronous observation stream from an upstream sampled frame stream.
    ///
    /// Ensures bounded concurrency (at most 1 active Vision inference at a time) and drops stale frames
    /// if Vision inference duration exceeds the sampling arrival rate.
    nonisolated func observationStream(
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
                        // Deliver safe empty observation fallback rather than breaking stream
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
    
    // MARK: - Metrics & Diagnostics
    
    func getMetrics() -> VisionServiceMetrics {
        metrics
    }
    
    func resetMetrics() {
        metrics = VisionServiceMetrics()
        totalLatencyAccumulatorMs = 0.0
    }
    
    private func recordMetrics(latencyMs: Double) {
        metrics.requestsCompleted += 1
        totalLatencyAccumulatorMs += latencyMs
        metrics.averageLatencyMs = totalLatencyAccumulatorMs / Double(metrics.requestsCompleted)
        metrics.lastObservationTimestamp = Date()
    }
    
    // MARK: - Private Vision Execution Helpers
    
    /// Executes both OCR and Rectangle detection in a single Vision request handler pass on a CVPixelBuffer.
    private func performVisionRequests(
        on pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async throws -> (texts: [DetectedText], regions: [DetectedRegion]) {
        try await withCheckedThrowingContinuation { continuation in
            var detectedTexts: [DetectedText] = []
            var detectedRegions: [DetectedRegion] = []
            
            let textRequest = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                detectedTexts = observations.compactMap { obs in
                    guard let topCandidate = obs.topCandidates(1).first else { return nil }
                    return DetectedText(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            
            let rectRequest = VNDetectRectanglesRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRectangleObservation] else {
                    return
                }
                detectedRegions = observations.enumerated().map { (index, obs) in
                    DetectedRegion(
                        label: "Component Slot #\(index + 1)",
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
            }
            rectRequest.minimumSize = 0.05
            rectRequest.maximumObservations = 16
            rectRequest.minimumConfidence = 0.35
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([textRequest, rectRequest])
                continuation.resume(returning: (detectedTexts, detectedRegions))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Executes both OCR and Rectangle detection in a single Vision request handler pass on a CGImage.
    private func performVisionRequests(
        on cgImage: CGImage
    ) async throws -> (texts: [DetectedText], regions: [DetectedRegion]) {
        try await withCheckedThrowingContinuation { continuation in
            var detectedTexts: [DetectedText] = []
            var detectedRegions: [DetectedRegion] = []
            
            let textRequest = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                detectedTexts = observations.compactMap { obs in
                    guard let topCandidate = obs.topCandidates(1).first else { return nil }
                    return DetectedText(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            
            let rectRequest = VNDetectRectanglesRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRectangleObservation] else {
                    return
                }
                detectedRegions = observations.enumerated().map { (index, obs) in
                    DetectedRegion(
                        label: "Component Slot #\(index + 1)",
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
            }
            rectRequest.minimumSize = 0.05
            rectRequest.maximumObservations = 16
            rectRequest.minimumConfidence = 0.35
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([textRequest, rectRequest])
                continuation.resume(returning: (detectedTexts, detectedRegions))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

