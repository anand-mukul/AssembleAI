//
//  VisualObservation.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Detected text observation extracted by Apple Vision OCR.
struct DetectedText: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect // Normalized [0...1] coordinates
    
    init(id: UUID = UUID(), text: String, confidence: Float, boundingBox: CGRect) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Detected physical component/region feature observation.
struct DetectedRegion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized [0...1] coordinates
    
    init(id: UUID = UUID(), label: String, confidence: Float, boundingBox: CGRect) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Structured output returned by `VisionAnalyzing` without exposing raw Vision framework types to the UI.
struct VisualObservation: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let imageSize: CGSize
    let detectedText: [DetectedText]
    let regions: [DetectedRegion]
    let timestamp: Date
    let processingTimeMs: Double
    
    init(
        id: UUID = UUID(),
        imageSize: CGSize,
        detectedText: [DetectedText],
        regions: [DetectedRegion],
        timestamp: Date = Date(),
        processingTimeMs: Double
    ) {
        self.id = id
        self.imageSize = imageSize
        self.detectedText = detectedText
        self.regions = regions
        self.timestamp = timestamp
        self.processingTimeMs = processingTimeMs
    }
    
    var hasText: Bool { !detectedText.isEmpty }
    var regionCount: Int { regions.count }
}
