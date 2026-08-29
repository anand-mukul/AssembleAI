//
//  VisionObservationService.swift
//  AssembleAI
//

import Foundation
import Vision
import UIKit

/// Structured output from Apple Vision framework analysis of a captured assembly frame.
struct VisionObservations: Sendable {
    /// Text strings recognized in the image (component markings, labels, values).
    let recognizedTexts: [String]
    
    /// Bounding rectangles of detected components in normalized image coordinates.
    let detectedRectangles: [CGRect]
    
    /// Number of distinct rectangular objects detected.
    var rectangleCount: Int { detectedRectangles.count }
    
    /// Whether any text was recognized in the frame.
    var hasText: Bool { !recognizedTexts.isEmpty }
    
    /// Checks if a specific marker string was detected (case-insensitive).
    func containsText(_ query: String) -> Bool {
        recognizedTexts.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// Isolated actor performing Apple Vision framework requests on captured assembly images.
/// Runs text recognition and rectangle detection to extract structured observations
/// that feed into the deterministic verification engine.
actor VisionObservationService {
    
    /// Analyzes a UIImage using Vision framework requests and returns structured observations.
    func analyze(image: UIImage) async throws -> VisionObservations {
        guard let cgImage = image.cgImage else {
            return VisionObservations(recognizedTexts: [], detectedRectangles: [])
        }
        
        async let texts = performTextRecognition(on: cgImage)
        async let rectangles = performRectangleDetection(on: cgImage)
        
        return VisionObservations(
            recognizedTexts: try await texts,
            detectedRectangles: try await rectangles
        )
    }
    
    // MARK: - Text Recognition (OCR)
    
    /// Runs VNRecognizeTextRequest to detect component markings like "10K", "100uF", "ATmega328P".
    private func performTextRecognition(on cgImage: CGImage) async throws -> [String] {
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
                
                let texts = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: texts)
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
    
    // MARK: - Rectangle Detection (Component Bounding Boxes)
    
    /// Runs VNDetectRectanglesRequest to identify rectangular component outlines on PCB surfaces.
    private func performRectangleDetection(on cgImage: CGImage) async throws -> [CGRect] {
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
                
                let rects = observations.map { $0.boundingBox }
                continuation.resume(returning: rects)
            }
            
            request.minimumSize = 0.05
            request.maximumObservations = 20
            request.minimumConfidence = 0.3
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
