//
//  SpatialAssemblyStateEstimator.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Precision spatial state estimator fusing Apple Vision observations with planar breadboard geometry.
///
/// Converts raw `VisualObservation` OCR strings, detected rectangles, and planar homography
/// into a structured `ObservedAssemblyState` with millimeter-accurate pin bindings.
nonisolated struct SpatialAssemblyStateEstimator: AssemblyStateEstimating {
    
    private let homographyService: BreadboardHomographyService
    private let spatialDetector: ComponentSpatialDetector
    private let calibrationProvider: (@Sendable () -> BreadboardCalibration?)?
    
    init(
        homographyService: BreadboardHomographyService = BreadboardHomographyService(),
        spatialDetector: ComponentSpatialDetector? = nil,
        calibrationProvider: (@Sendable () -> BreadboardCalibration?)? = nil
    ) {
        self.homographyService = homographyService
        self.spatialDetector = spatialDetector ?? ComponentSpatialDetector(homographyService: homographyService)
        self.calibrationProvider = calibrationProvider
    }
    
    func estimate(observation: VisualObservation) async throws -> ObservedAssemblyState {
        // Resolve active calibration (or fall back to default centered workbench pose)
        let calibration = calibrationProvider?() ?? BreadboardCalibration.defaultCentered()
        
        // 1. Detect spatial components
        let spatialComponents = spatialDetector.detectComponents(in: observation, calibration: calibration)
        
        var observedComponents: [ObservedComponent] = []
        var observedPositions: [ObservedPosition] = []
        var observedConnections: [ObservedConnection] = []
        
        for comp in spatialComponents {
            // Map to ObservedComponent
            observedComponents.append(
                ObservedComponent(
                    id: comp.id,
                    identifier: comp.partId,
                    name: comp.name,
                    confidence: comp.confidence,
                    boundingBox: comp.cameraBoundingBox
                )
            )
            
            // Map pin positions to ObservedPosition
            if let fromPin = comp.fromPin {
                let targetDesc: String
                if let toPin = comp.toPin {
                    targetDesc = "\(fromPin.label) to \(toPin.label)"
                } else {
                    targetDesc = fromPin.label
                }
                
                observedPositions.append(
                    ObservedPosition(
                        componentID: comp.partId ?? "comp_\(comp.id.uuidString.prefix(4))",
                        detectedDescription: targetDesc,
                        region: comp.cameraBoundingBox,
                        confidence: comp.confidence
                    )
                )
            }
        }
        
        // 2. Derive wire / rail connections from detected text markings and pin observations
        for textObs in observation.detectedText {
            let text = textObs.text
            let conf = Double(textObs.confidence)
            if text.localizedCaseInsensitiveContains("GND") {
                observedConnections.append(
                    ObservedConnection(from: "GND Rail", to: "Pin Header", confidence: conf)
                )
            } else if text.localizedCaseInsensitiveContains("5V") || text.localizedCaseInsensitiveContains("VCC") {
                observedConnections.append(
                    ObservedConnection(from: "VCC Rail", to: "Pin Header", confidence: conf)
                )
            }
        }
        
        // If components bridged pins, register connection
        for comp in spatialComponents {
            if let f = comp.fromPin, let t = comp.toPin {
                observedConnections.append(
                    ObservedConnection(from: f.label, to: t.label, confidence: comp.confidence)
                )
            }
        }
        
        // 3. Compute overall evidence confidence
        let confidenceScore: Double
        if observedComponents.isEmpty && observedPositions.isEmpty {
            confidenceScore = 0.35 // Insufficient visual evidence
        } else {
            let compScores = observedComponents.map(\.confidence)
            let avgScore = compScores.reduce(0.0, +) / Double(max(1, compScores.count))
            confidenceScore = min(0.98, max(0.40, avgScore))
        }
        
        return ObservedAssemblyState(
            detectedComponents: observedComponents,
            detectedConnections: observedConnections,
            detectedPositions: observedPositions,
            overallConfidence: confidenceScore,
            timestamp: observation.timestamp
        )
    }
}
