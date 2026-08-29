//
//  VisionCoordinateMapper.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import UIKit

/// Isolated utility mapping Vision normalized bounding box coordinates [0...1] (bottom-left origin) to SwiftUI overlay view coordinates (top-left origin).
struct VisionCoordinateMapper: Sendable {
    
    /// Converts a Vision normalized bounding box to screen overlay coordinates matching `aspectFill` camera preview layers.
    ///
    /// - Parameters:
    ///   - visionBox: Normalized CGRect from Vision [minX, minY, width, height] in range 0.0...1.0.
    ///   - imageSize: Original image dimensions.
    ///   - viewSize: Screen bounds of the SwiftUI container view.
    /// - Returns: Bounding box mapped to screen coordinates (top-left origin).
    static func mapVisionBox(
        _ visionBox: CGRect,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0 && imageSize.height > 0 && viewSize.width > 0 && viewSize.height > 0 else {
            return .zero
        }
        
        // Calculate scale factor for Aspect Fill
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let aspectFillScale = max(scaleX, scaleY)
        
        let scaledImageWidth = imageSize.width * aspectFillScale
        let scaledImageHeight = imageSize.height * aspectFillScale
        
        // Aspect fill cropping offsets
        let offsetX = (scaledImageWidth - viewSize.width) / 2.0
        let offsetY = (scaledImageHeight - viewSize.height) / 2.0
        
        // Un-normalize Vision box to scaled image dimensions
        let boxWidth = visionBox.width * scaledImageWidth
        let boxHeight = visionBox.height * scaledImageHeight
        let boxMinX = visionBox.minX * scaledImageWidth
        let boxMinY = (1.0 - visionBox.maxY) * scaledImageHeight // Flip Vision bottom-left Y to top-left Y
        
        // Apply aspect fill offset
        let screenX = boxMinX - offsetX
        let screenY = boxMinY - offsetY
        
        return CGRect(x: screenX, y: screenY, width: boxWidth, height: boxHeight)
    }
}
