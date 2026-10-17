//
//  VisualObservation.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Detected text observation extracted by Apple Vision OCR.
nonisolated struct DetectedText: Identifiable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect // Normalized [0...1] coordinates
    
    nonisolated init(id: UUID = UUID(), text: String, confidence: Float = 1.0, boundingBox: CGRect = .zero) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
    
    nonisolated init(stringLiteral value: String) {
        self.init(text: value, confidence: 1.0, boundingBox: .zero)
    }
}

/// Convenience alias for text detection element
typealias RecognizedTextElement = DetectedText

/// Detected physical component/region feature observation.
nonisolated struct DetectedRegion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized [0...1] coordinates
    
    nonisolated init(id: UUID = UUID(), label: String, confidence: Float = 1.0, boundingBox: CGRect = .zero) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Taxonomical scene/object classification observation from Apple Vision.
nonisolated struct DetectedClassification: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let identifier: String
    let confidence: Float
    
    nonisolated init(id: UUID = UUID(), identifier: String, confidence: Float) {
        self.id = id
        self.identifier = identifier
        self.confidence = confidence
    }
}

/// Structured output returned by `VisionAnalyzing` without exposing raw Vision framework types to the UI.
nonisolated struct VisualObservation: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let imageSize: CGSize
    let detectedText: [DetectedText]
    let regions: [DetectedRegion]
    let classifications: [DetectedClassification]
    let detectedHumans: [CGRect]
    let timestamp: Date
    let processingTimeMs: Double
    
    nonisolated init(
        id: UUID = UUID(),
        imageSize: CGSize = CGSize(width: 1920, height: 1080),
        detectedText: [DetectedText] = [],
        regions: [DetectedRegion] = [],
        classifications: [DetectedClassification] = [],
        sceneClassification: String? = nil,
        detectedHumans: [CGRect] = [],
        timestamp: Date = Date(),
        processingTimeMs: Double = 0.0
    ) {
        self.id = id
        self.imageSize = imageSize
        self.detectedText = detectedText
        self.regions = regions
        var resolvedClassifications = classifications
        if let sc = sceneClassification {
            resolvedClassifications.append(DetectedClassification(identifier: sc, confidence: 1.0))
        }
        self.classifications = resolvedClassifications
        self.detectedHumans = detectedHumans
        self.timestamp = timestamp
        self.processingTimeMs = processingTimeMs
    }
    
    nonisolated init(
        id: UUID = UUID(),
        imageSize: CGSize,
        detectedStrings: [String],
        regions: [DetectedRegion] = [],
        classifications: [DetectedClassification] = [],
        detectedHumans: [CGRect] = [],
        timestamp: Date = Date(),
        processingTimeMs: Double
    ) {
        self.id = id
        self.imageSize = imageSize
        self.detectedText = detectedStrings.map { DetectedText(text: $0, confidence: 1.0, boundingBox: .zero) }
        self.regions = regions
        self.classifications = classifications
        self.detectedHumans = detectedHumans
        self.timestamp = timestamp
        self.processingTimeMs = processingTimeMs
    }
    
    var hasText: Bool { !detectedText.isEmpty }
    var regionCount: Int { regions.count }
    var isHumanPresent: Bool { !detectedHumans.isEmpty }
    var topClassification: String? { classifications.first?.identifier }
    
    func hasClassification(matching keyword: String) -> Bool {
        let kw = keyword.lowercased()
        return classifications.contains { $0.identifier.lowercased().contains(kw) }
    }
}
