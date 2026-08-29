//
//  VisionAnalyzing.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Protocol for analyzing captured camera images using computer vision algorithms.
protocol VisionAnalyzing: Sendable {
    /// Analyzes a captured image and produces structured visual observations.
    func analyze(image: UIImage) async throws -> VisualObservation
}
