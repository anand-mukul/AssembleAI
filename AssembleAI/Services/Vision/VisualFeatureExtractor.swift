//
//  VisualFeatureExtractor.swift
//  AssembleAI
//
//  On-device visual perception engine extracting salient physical objects,
//  deep neural visual feature prints, color signatures, and contours.
//

import Foundation
import Vision
import CoreVideo
import CoreGraphics
import UIKit

/// Detected foreground physical object on the workbench.
public struct SalientPhysicalObject: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let boundingBox: CGRect // Normalized [0...1] coordinates
    public let confidence: Float
    public let categoryLabel: String
    public let dominantColor: String?
    public let aspectRatio: CGFloat
    
    public init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        confidence: Float,
        categoryLabel: String = "Physical Component",
        dominantColor: String? = nil,
        aspectRatio: CGFloat = 1.0
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.categoryLabel = categoryLabel
        self.dominantColor = dominantColor
        self.aspectRatio = aspectRatio
    }
}

/// On-device visual perception engine fusing Apple Vision framework requests.
public final class VisualFeatureExtractor: @unchecked Sendable {
    public static let shared = VisualFeatureExtractor()
    
    public init() {}
    
    // MARK: - Salient Object Detection
    
    /// Detects salient physical components and objects placed on the workspace or held by the user.
    public func extractSalientObjects(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) async -> [SalientPhysicalObject] {
        return await withCheckedContinuation { continuation in
            var objects: [SalientPhysicalObject] = []
            
            let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                guard error == nil, let results = request.results as? [VNSaliencyImageObservation] else {
                    return
                }
                
                for observation in results {
                    let salientObjects = observation.salientObjects ?? []
                    for (index, obj) in salientObjects.enumerated() {
                        let box = obj.boundingBox
                        // Filter out tiny artifacts or full-screen frames
                        guard box.width >= 0.04, box.height >= 0.04, box.width <= 0.95, box.height <= 0.95 else {
                            continue
                        }
                        
                        let aspect = box.height > 0 ? box.width / box.height : 1.0
                        let label: String
                        if aspect > 2.5 || aspect < 0.4 {
                            label = "Lead / Wire Component"
                        } else if box.width > 0.4 || box.height > 0.4 {
                            label = "Workpiece / Panel"
                        } else {
                            label = "Component #\(index + 1)"
                        }
                        
                        let detectedObj = SalientPhysicalObject(
                            boundingBox: box,
                            confidence: obj.confidence,
                            categoryLabel: label,
                            dominantColor: nil,
                            aspectRatio: aspect
                        )
                        objects.append(detectedObj)
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([saliencyRequest])
            } catch {
                // Return gracefully if request fails
            }
            
            // Enrich detected objects with dominant color sampling
            let enriched = objects.map { obj -> SalientPhysicalObject in
                let color = self.sampleDominantColor(in: obj.boundingBox, pixelBuffer: pixelBuffer)
                return SalientPhysicalObject(
                    id: obj.id,
                    boundingBox: obj.boundingBox,
                    confidence: obj.confidence,
                    categoryLabel: color.map { "\($0) \(obj.categoryLabel)" } ?? obj.categoryLabel,
                    dominantColor: color,
                    aspectRatio: obj.aspectRatio
                )
            }
            
            continuation.resume(returning: enriched)
        }
    }
    
    // MARK: - Neural Visual Feature Prints (Visual Similarity)
    
    /// Computes a normalized deep neural feature print observation for visual comparison.
    public func computeFeaturePrint(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) async -> VNFeaturePrintObservation? {
        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
                let result = request.results?.first as? VNFeaturePrintObservation
                continuation.resume(returning: result)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Computes visual similarity between two feature prints as a normalized score [0.0 ... 1.0].
    public func computeSimilarity(
        between printA: VNFeaturePrintObservation,
        and printB: VNFeaturePrintObservation
    ) -> Float {
        var distance: Float = 1.0
        do {
            try printA.computeDistance(&distance, to: printB)
            // Vision feature print distance: 0.0 is identical, > 1.0 is dissimilar
            return max(0.0, min(1.0, 1.0 - (distance / 2.0)))
        } catch {
            return 0.5
        }
    }
    
    // MARK: - Contour Detection
    
    /// Traces high-contrast physical edges and wire outlines.
    public func detectContours(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) async -> [CGRect] {
        return await withCheckedContinuation { continuation in
            let contourRequest = VNDetectContoursRequest()
            contourRequest.contrastAdjustment = 1.2
            contourRequest.detectsDarkOnLight = true
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([contourRequest])
                guard let observation = contourRequest.results?.first as? VNContoursObservation else {
                    continuation.resume(returning: [])
                    return
                }
                
                var boxes: [CGRect] = []
                for i in 0..<min(observation.contourCount, 15) {
                    if let contour = try? observation.contour(at: i), contour.pointCount > 8 {
                        let path = contour.normalizedPath
                        let bounds = path.boundingBox
                        if bounds.width > 0.05 && bounds.height > 0.05 {
                            boxes.append(bounds)
                        }
                    }
                }
                continuation.resume(returning: boxes)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Dominant Color Analysis
    
    /// Samples pixel buffer colors within a normalized bounding box to determine dominant component hue.
    public func sampleDominantColor(in normalizedBox: CGRect, pixelBuffer: CVPixelBuffer) -> String? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return nil }
        
        let startX = max(0, min(width - 1, Int(normalizedBox.minX * CGFloat(width))))
        let endX = max(0, min(width - 1, Int(normalizedBox.maxX * CGFloat(width))))
        let startY = max(0, min(height - 1, Int(normalizedBox.minY * CGFloat(height))))
        let endY = max(0, min(height - 1, Int(normalizedBox.maxY * CGFloat(height))))
        
        guard endX > startX, endY > startY else { return nil }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var redSum: Int = 0
        var greenSum: Int = 0
        var blueSum: Int = 0
        var sampleCount: Int = 0
        
        // Sample points across grid
        let stepX = max(1, (endX - startX) / 8)
        let stepY = max(1, (endY - startY) / 8)
        
        for y in stride(from: startY, to: endY, by: stepY) {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            let buffer = row.assumingMemoryBound(to: UInt8.self)
            for x in stride(from: startX, to: endX, by: stepX) {
                // BGRA format standard in iOS AVCapture
                let b = Int(buffer[x * 4])
                let g = Int(buffer[x * 4 + 1])
                let r = Int(buffer[x * 4 + 2])
                
                redSum += r
                greenSum += g
                blueSum += b
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return nil }
        
        let avgR = redSum / sampleCount
        let avgG = greenSum / sampleCount
        let avgB = blueSum / sampleCount
        
        // Classify dominant color
        if avgR > 140 && avgG < 90 && avgB < 90 {
            return "Red"
        } else if avgB > 130 && avgR < 100 {
            return "Blue"
        } else if avgG > 120 && avgR < 110 && avgB < 110 {
            return "Green"
        } else if avgR > 150 && avgG > 130 && avgB < 70 {
            return "Yellow"
        } else if avgR > 140 && avgG > 100 && avgB < 70 {
            return "Wood Tone"
        } else if avgR > 180 && avgG > 180 && avgB > 180 {
            return "Silver / White"
        } else if avgR < 60 && avgG < 60 && avgB < 60 {
            return "Black / Dark"
        }
        
        return nil
    }
}
