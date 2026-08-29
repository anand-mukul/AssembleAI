//
//  AssemblyStateEstimator.swift
//  AssembleAI
//

import Foundation

/// Protocol for estimating observed physical assembly state from structured visual observations.
protocol AssemblyStateEstimating: Sendable {
    /// Converts a low-level `VisualObservation` into a higher-level domain `ObservedAssemblyState`.
    func estimate(observation: VisualObservation) async throws -> ObservedAssemblyState
}

/// Concrete estimator converting Vision OCR text markings and region bounding boxes into structured observed state.
nonisolated struct VisionAssemblyStateEstimator: AssemblyStateEstimating {
    
    func estimate(observation: VisualObservation) async throws -> ObservedAssemblyState {
        var observedComponents: [ObservedComponent] = []
        var observedPositions: [ObservedPosition] = []
        var observedConnections: [ObservedConnection] = []
        
        // 1. Process recognized OCR texts
        for textObs in observation.detectedText {
            let text = textObs.text
            let conf = Double(textObs.confidence)
            
            if text.localizedCaseInsensitiveContains("220") || text.localizedCaseInsensitiveContains("10K") {
                observedComponents.append(
                    ObservedComponent(
                        identifier: "resistor_220",
                        name: "220Ω Resistor",
                        confidence: conf,
                        boundingBox: textObs.boundingBox
                    )
                )
            } else if text.localizedCaseInsensitiveContains("LED") || text.localizedCaseInsensitiveContains("LIGHT") {
                observedComponents.append(
                    ObservedComponent(
                        identifier: "led_red",
                        name: "Red LED",
                        confidence: conf,
                        boundingBox: textObs.boundingBox
                    )
                )
            } else if text.localizedCaseInsensitiveContains("GND") || text.localizedCaseInsensitiveContains("5V") {
                let isGND = text.localizedCaseInsensitiveContains("GND")
                observedConnections.append(
                    ObservedConnection(
                        from: isGND ? "GND Rail" : "5V Rail",
                        to: "Pin Header",
                        confidence: conf
                    )
                )
            } else {
                // Unknown/Uncertain component text
                observedComponents.append(
                    ObservedComponent(
                        identifier: nil,
                        name: "Unidentified Text Marking (\(text))",
                        confidence: min(0.45, conf),
                        boundingBox: textObs.boundingBox
                    )
                )
            }
        }
        
        // 2. Process detected region slots
        for region in observation.regions {
            observedPositions.append(
                ObservedPosition(
                    componentID: "slot_\(region.id.uuidString.prefix(4))",
                    detectedDescription: region.label,
                    region: region.boundingBox,
                    confidence: Double(region.confidence)
                )
            )
        }
        
        // Compute overall confidence score
        let confidenceScore: Double
        if observedComponents.isEmpty && observedPositions.isEmpty {
            confidenceScore = 0.35 // Insufficient visual evidence
        } else {
            let compConf = observedComponents.map(\.confidence).reduce(0.0, +)
            let totalItems = Double(observedComponents.count + observedPositions.count)
            confidenceScore = min(0.98, max(0.40, (compConf + Double(observedPositions.count) * 0.7) / totalItems))
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
