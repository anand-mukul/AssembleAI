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
nonisolated struct VisionServiceMetrics: Sendable, Equatable {
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
        let (texts, regions, classifications, humans) = try await performVisionRequests(on: cgImage)
        
        try Task.checkCancellation()
        
        let elapsedTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        recordMetrics(latencyMs: elapsedTimeMs)
        
        return VisualObservation(
            imageSize: imageSize,
            detectedText: texts,
            regions: regions,
            classifications: classifications,
            detectedHumans: humans,
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
        let (texts, regions, classifications, humans) = try await performVisionRequests(on: frame, orientation: orientation)
        
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
            classifications: classifications,
            detectedHumans: humans,
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
                            detectedText: [DetectedText](),
                            regions: [],
                            classifications: [],
                            detectedHumans: [],
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
    
    /// Executes OCR, Rectangle detection, Salient Object detection, Taxonomical Classification, and Human Presence detection
    /// in a single fused Vision request handler pass on a CVPixelBuffer.
    private func performVisionRequests(
        on pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async throws -> (texts: [DetectedText], regions: [DetectedRegion], classifications: [DetectedClassification], humans: [CGRect]) {
        try await withCheckedThrowingContinuation { continuation in
            var detectedTexts: [DetectedText] = []
            var detectedRegions: [DetectedRegion] = []
            var detectedClassifications: [DetectedClassification] = []
            var detectedHumans: [CGRect] = []
            
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
                for (index, obs) in observations.enumerated() {
                    detectedRegions.append(
                        DetectedRegion(
                            label: "Boundary Slot #\(index + 1)",
                            confidence: obs.confidence,
                            boundingBox: obs.boundingBox
                        )
                    )
                }
            }
            rectRequest.minimumSize = 0.08
            rectRequest.maximumObservations = 6
            rectRequest.minimumConfidence = 0.50
            rectRequest.minimumAspectRatio = 0.15
            rectRequest.maximumAspectRatio = 1.0
            
            let classifyRequest = VNClassifyImageRequest { request, error in
                guard error == nil, let observations = request.results as? [VNClassificationObservation] else {
                    return
                }
                detectedClassifications = observations
                    .filter { $0.confidence >= 0.15 }
                    .prefix(12)
                    .map { DetectedClassification(identifier: $0.identifier, confidence: $0.confidence) }
            }
            
            let humanRequest = VNDetectHumanRectanglesRequest { request, error in
                guard error == nil, let observations = request.results as? [VNHumanObservation] else {
                    return
                }
                detectedHumans = observations.map { $0.boundingBox }
            }
            
            let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                guard error == nil, let results = request.results as? [VNSaliencyImageObservation] else {
                    return
                }
                for obs in results {
                    let salients = obs.salientObjects ?? []
                    for (idx, obj) in salients.enumerated() {
                        let box = obj.boundingBox
                        guard box.width >= 0.03, box.height >= 0.03, box.width <= 0.95, box.height <= 0.95 else { continue }
                        let aspect = box.height > 0 ? box.width / box.height : 1.0
                        let label: String
                        if aspect > 2.5 || aspect < 0.4 {
                            label = "Lead / Wire Line"
                        } else if box.width > 0.4 || box.height > 0.4 {
                            label = "Main Workpiece / Panel"
                        } else {
                            label = "Physical Part #\(idx + 1)"
                        }
                        detectedRegions.append(
                            DetectedRegion(
                                label: label,
                                confidence: obj.confidence,
                                boundingBox: box
                            )
                        )
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([textRequest, rectRequest])
                try? handler.perform([classifyRequest, humanRequest, saliencyRequest])
                continuation.resume(returning: (detectedTexts, detectedRegions, detectedClassifications, detectedHumans))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Executes OCR, Rectangle detection, Salient Object detection, Taxonomical Classification, and Human Presence detection
    /// in a single fused Vision request handler pass on a CGImage.
    private func performVisionRequests(
        on cgImage: CGImage
    ) async throws -> (texts: [DetectedText], regions: [DetectedRegion], classifications: [DetectedClassification], humans: [CGRect]) {
        try await withCheckedThrowingContinuation { continuation in
            var detectedTexts: [DetectedText] = []
            var detectedRegions: [DetectedRegion] = []
            var detectedClassifications: [DetectedClassification] = []
            var detectedHumans: [CGRect] = []
            
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
                for (index, obs) in observations.enumerated() {
                    detectedRegions.append(
                        DetectedRegion(
                            label: "Boundary Slot #\(index + 1)",
                            confidence: obs.confidence,
                            boundingBox: obs.boundingBox
                        )
                    )
                }
            }
            rectRequest.minimumSize = 0.08
            rectRequest.maximumObservations = 6
            rectRequest.minimumConfidence = 0.50
            rectRequest.minimumAspectRatio = 0.15
            rectRequest.maximumAspectRatio = 1.0
            
            let classifyRequest = VNClassifyImageRequest { request, error in
                guard error == nil, let observations = request.results as? [VNClassificationObservation] else {
                    return
                }
                detectedClassifications = observations
                    .filter { $0.confidence >= 0.15 }
                    .prefix(12)
                    .map { DetectedClassification(identifier: $0.identifier, confidence: $0.confidence) }
            }
            
            let humanRequest = VNDetectHumanRectanglesRequest { request, error in
                guard error == nil, let observations = request.results as? [VNHumanObservation] else {
                    return
                }
                detectedHumans = observations.map { $0.boundingBox }
            }
            
            let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                guard error == nil, let results = request.results as? [VNSaliencyImageObservation] else {
                    return
                }
                for obs in results {
                    let salients = obs.salientObjects ?? []
                    for (idx, obj) in salients.enumerated() {
                        let box = obj.boundingBox
                        guard box.width >= 0.03, box.height >= 0.03, box.width <= 0.95, box.height <= 0.95 else { continue }
                        let aspect = box.height > 0 ? box.width / box.height : 1.0
                        let label: String
                        if aspect > 2.5 || aspect < 0.4 {
                            label = "Lead / Wire Line"
                        } else if box.width > 0.4 || box.height > 0.4 {
                            label = "Main Workpiece / Panel"
                        } else {
                            label = "Physical Part #\(idx + 1)"
                        }
                        detectedRegions.append(
                            DetectedRegion(
                                label: label,
                                confidence: obj.confidence,
                                boundingBox: box
                            )
                        )
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([textRequest, rectRequest])
                try? handler.perform([classifyRequest, humanRequest, saliencyRequest])
                continuation.resume(returning: (detectedTexts, detectedRegions, detectedClassifications, detectedHumans))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

