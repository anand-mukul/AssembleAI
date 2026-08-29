//
//  VisionService.swift
//  AssembleAI
//

import Foundation
import Vision
import UIKit

/// Concrete computer vision analysis service using Apple's Vision framework (VNRecognizeTextRequest + VNDetectRectanglesRequest).
actor VisionService: VisionAnalyzing {
    private let imageProcessor = ImageProcessingService()
    
    func analyze(image: UIImage) async throws -> VisualObservation {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Preprocess image (fix orientation and optimize resolution)
        let preparedImage = imageProcessor.prepareImageForVision(image)
        
        guard let cgImage = preparedImage.cgImage else {
            throw NSError(domain: "VisionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image format"])
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        async let texts = performTextRecognition(on: cgImage)
        async let regions = performRectangleDetection(on: cgImage)
        
        let recognizedTexts = try await texts
        let detectedRegions = try await regions
        
        let elapsedTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        
        return VisualObservation(
            imageSize: imageSize,
            detectedText: recognizedTexts,
            regions: detectedRegions,
            processingTimeMs: elapsedTimeMs
        )
    }
    
    // MARK: - VNRecognizeTextRequest (OCR)
    
    private func performTextRecognition(on cgImage: CGImage) async throws -> [DetectedText] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let detected = observations.compactMap { obs -> DetectedText? in
                    guard let topCandidate = obs.topCandidates(1).first else { return nil }
                    return DetectedText(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
                
                continuation.resume(returning: detected)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - VNDetectRectanglesRequest (Component Bounding Box Detection)
    
    private func performRectangleDetection(on cgImage: CGImage) async throws -> [DetectedRegion] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let regions = observations.enumerated().map { (index, obs) in
                    DetectedRegion(
                        label: "Component Slot #\(index + 1)",
                        confidence: obs.confidence,
                        boundingBox: obs.boundingBox
                    )
                }
                
                continuation.resume(returning: regions)
            }
            
            request.minimumSize = 0.05
            request.maximumObservations = 16
            request.minimumConfidence = 0.35
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
