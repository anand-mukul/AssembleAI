//
//  LEDEmissionDetector.swift
//  AssembleAI
//
//  Detects whether an LED component in the camera frame is currently emitting
//  light by analyzing pixel brightness in the component's bounding region.
//  Uses CoreImage pixel averaging for efficient on-device luminance analysis.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import UIKit

// MARK: - LED Emission Result

/// Result of LED emission (on/off) analysis for a detected component region.
nonisolated struct LEDEmissionResult: Sendable, Equatable {
    /// Whether the LED appears to be emitting light.
    let isEmitting: Bool
    /// Average brightness (0.0–1.0) in the analyzed region.
    let averageBrightness: Double
    /// Peak brightness (0.0–1.0) detected in the region.
    let peakBrightness: Double
    /// Human-readable description for tutor speech.
    let description: String
    
    static let unknown = LEDEmissionResult(
        isEmitting: false,
        averageBrightness: 0.0,
        peakBrightness: 0.0,
        description: "LED state could not be determined."
    )
}

// MARK: - LED Emission Detector

/// Analyzes camera frames to determine if LED components are currently emitting light.
///
/// Uses a two-pass approach:
/// 1. Average brightness in the LED bounding region (CIAreaAverage filter)
/// 2. Peak brightness check for saturated bright spots typical of active LEDs
nonisolated struct LEDEmissionDetector: Sendable {
    
    /// Brightness threshold above which the LED is considered "on" (0.0–1.0).
    /// LEDs typically show brightness > 0.7 when actively emitting.
    private let emissionThreshold: Double
    
    /// Peak brightness threshold for detecting a saturated bright spot.
    private let peakThreshold: Double
    
    nonisolated init(
        emissionThreshold: Double = 0.65,
        peakThreshold: Double = 0.85
    ) {
        self.emissionThreshold = emissionThreshold
        self.peakThreshold = peakThreshold
    }
    
    /// Analyzes a CVPixelBuffer camera frame directly for LED emission.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The raw camera frame.
    ///   - region: Normalized bounding box (0.0–1.0), defaults to full frame.
    /// - Returns: LED emission analysis result.
    func detectEmission(
        in pixelBuffer: CVPixelBuffer,
        normalizedRegion region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) -> LEDEmissionResult {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        let extent = ciImage.extent
        let pixelRect = CGRect(
            x: extent.origin.x + region.origin.x * extent.width,
            y: extent.origin.y + region.origin.y * extent.height,
            width: region.size.width * extent.width,
            height: region.size.height * extent.height
        ).integral
        
        let clampedRect = pixelRect.intersection(extent)
        guard !clampedRect.isEmpty, clampedRect.width > 2, clampedRect.height > 2 else {
            return .unknown
        }
        
        let cropped = ciImage.cropped(to: clampedRect)
        let averageBrightness = computeAverageBrightness(ciImage: cropped, context: context)
        let peakBrightness = computePeakBrightness(ciImage: cropped, context: context)
        
        let isEmitting = averageBrightness > emissionThreshold || peakBrightness > peakThreshold
        let description = isEmitting
            ? "LED is active and illuminated (brightness: \(String(format: "%.0f", peakBrightness * 100))%)."
            : "LED appears to be OFF (brightness: \(String(format: "%.0f", averageBrightness * 100))%)."
        
        return LEDEmissionResult(
            isEmitting: isEmitting,
            averageBrightness: averageBrightness,
            peakBrightness: peakBrightness,
            description: description
        )
    }
    
    /// Analyzes a region of the camera frame to determine LED emission state.
    ///
    /// - Parameters:
    ///   - image: The full camera frame as CGImage.
    ///   - region: Normalized bounding box (0.0–1.0) of the detected LED component.
    /// - Returns: LED emission analysis result.
    func detectEmission(in image: CGImage, normalizedRegion region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> LEDEmissionResult {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        
        // Convert normalized coordinates to pixel coordinates
        let pixelRect = CGRect(
            x: region.origin.x * imageWidth,
            y: region.origin.y * imageHeight,
            width: region.size.width * imageWidth,
            height: region.size.height * imageHeight
        ).integral
        
        // Ensure region is within image bounds
        let clampedRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard !clampedRect.isEmpty, clampedRect.width > 2, clampedRect.height > 2 else {
            return .unknown
        }
        
        // Crop to LED region
        guard let cropped = image.cropping(to: clampedRect) else {
            return .unknown
        }
        
        let ciImage = CIImage(cgImage: cropped)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        // Pass 1: Average brightness using CIAreaAverage
        let averageBrightness = computeAverageBrightness(ciImage: ciImage, context: context)
        
        // Pass 2: Peak brightness using CIAreaMaximum
        let peakBrightness = computePeakBrightness(ciImage: ciImage, context: context)
        
        let isEmitting = averageBrightness > emissionThreshold || peakBrightness > peakThreshold
        
        let description: String
        if isEmitting {
            if peakBrightness > 0.9 {
                description = "LED is ON — bright emission detected (brightness: \(String(format: "%.0f", peakBrightness * 100))%)."
            } else {
                description = "LED appears to be ON — moderate emission detected."
            }
        } else {
            description = "LED appears to be OFF — no significant light emission detected."
        }
        
        return LEDEmissionResult(
            isEmitting: isEmitting,
            averageBrightness: averageBrightness,
            peakBrightness: peakBrightness,
            description: description
        )
    }
    
    /// Analyzes a UIImage for LED emission in the given normalized region.
    func detectEmission(in image: UIImage, normalizedRegion region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> LEDEmissionResult {
        guard let cgImage = image.cgImage else { return .unknown }
        return detectEmission(in: cgImage, normalizedRegion: region)
    }
    
    // MARK: - Private Helpers
    
    private func computeAverageBrightness(ciImage: CIImage, context: CIContext) -> Double {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]),
        let outputImage = filter.outputImage else {
            return 0.0
        }
        
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        // Calculate perceived brightness using luminance formula
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    private func computePeakBrightness(ciImage: CIImage, context: CIContext) -> Double {
        guard let filter = CIFilter(name: "CIAreaMaximum", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]),
        let outputImage = filter.outputImage else {
            return 0.0
        }
        
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return max(r, max(g, b))
    }
}
