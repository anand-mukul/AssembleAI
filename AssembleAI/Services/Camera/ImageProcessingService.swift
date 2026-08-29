//
//  ImageProcessingService.swift
//  AssembleAI
//

import Foundation
import UIKit
import CoreGraphics

/// Service preparing captured camera images for Apple Vision framework analysis and coordinate mapping.
struct ImageProcessingService: Sendable {
    
    /// Normalizes image orientation and resizes if necessary to optimize memory usage during Vision requests.
    func prepareImageForVision(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        // 1. Fix Orientation
        let normalized = fixOrientation(image)
        
        // 2. Downscale if max dimension exceeds limit
        let size = normalized.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return normalized
        }
        
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Returns orientation-corrected UIImage.
    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalized ?? image
    }
    
    /// Converts a normalized Vision bounding box [0...1] (bottom-left origin) to standard SwiftUI view coordinates (top-left origin).
    static func convertVisionBoundingBox(_ visionBox: CGRect, to viewSize: CGSize) -> CGRect {
        let width = visionBox.width * viewSize.width
        let height = visionBox.height * viewSize.height
        let x = visionBox.minX * viewSize.width
        let y = (1.0 - visionBox.maxY) * viewSize.height // Flip Y axis
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
