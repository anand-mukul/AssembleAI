//
//  ComponentSpatialDetector.swift
//  AssembleAI
//

import Foundation
import CoreGraphics
import Vision
import UIKit

/// Result of spatial component detection in the camera frame.
nonisolated struct SpatiallyDetectedComponent: Identifiable, Sendable, Equatable {
    let id: UUID
    let partId: String?
    let componentType: ComponentType
    let name: String
    let confidence: Double
    let cameraBoundingBox: CGRect
    
    // Physical coordinate bindings
    let fromPin: PinCoordinate?
    let toPin: PinCoordinate?
    let detectedColorBands: [String]
    let detectedMarkerType: OrientationMarkerType
    let orientationDegrees: Double?
    
    init(
        id: UUID = UUID(),
        partId: String? = nil,
        componentType: ComponentType,
        name: String,
        confidence: Double,
        cameraBoundingBox: CGRect,
        fromPin: PinCoordinate? = nil,
        toPin: PinCoordinate? = nil,
        detectedColorBands: [String] = [],
        detectedMarkerType: OrientationMarkerType = .notApplicable,
        orientationDegrees: Double? = nil
    ) {
        self.id = id
        self.partId = partId
        self.componentType = componentType
        self.name = name
        self.confidence = confidence
        self.cameraBoundingBox = cameraBoundingBox
        self.fromPin = fromPin
        self.toPin = toPin
        self.detectedColorBands = detectedColorBands
        self.detectedMarkerType = detectedMarkerType
        self.orientationDegrees = orientationDegrees
    }
}

/// On-device spatial component detector interpreting visual observations and breadboard geometry.
nonisolated struct ComponentSpatialDetector: Sendable {
    
    private let homographyService: BreadboardHomographyService
    
    init(homographyService: BreadboardHomographyService = BreadboardHomographyService()) {
        self.homographyService = homographyService
    }
    
    /// Detects components from high-level visual observation and optional breadboard calibration.
    func detectComponents(
        in observation: VisualObservation,
        calibration: BreadboardCalibration?
    ) -> [SpatiallyDetectedComponent] {
        var detected: [SpatiallyDetectedComponent] = []
        
        // 1. Analyze OCR texts for component value or pin markings
        for textObs in observation.detectedText {
            let text = textObs.text
            let conf = Double(textObs.confidence)
            let box = textObs.boundingBox
            let center = CGPoint(x: box.midX, y: box.midY)
            
            // Map pin coordinates if calibration is available
            let pinInfo = calibration.flatMap { homographyService.mapCameraPointToPin(cameraPoint: center, calibration: $0) }
            
            // Check for Resistors
            if text.localizedCaseInsensitiveContains("220") || text.localizedCaseInsensitiveContains("10K") || text.localizedCaseInsensitiveContains("RES") {
                let is220 = text.localizedCaseInsensitiveContains("220")
                let defaultBands = is220 ? ["red", "red", "brown", "gold"] : ["brown", "black", "orange", "gold"]
                let name = is220 ? "220Ω Resistor" : "10K Resistor"
                let partId = is220 ? "part_res_220" : "part_res_10k"
                
                let fromPin = pinInfo?.pin ?? PinCoordinate(row: "10", column: "E")
                let toPin = PinCoordinate(row: is220 ? "15" : "15", column: "F")
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: partId,
                        componentType: .resistor,
                        name: name,
                        confidence: max(0.65, conf),
                        cameraBoundingBox: box,
                        fromPin: fromPin,
                        toPin: toPin,
                        detectedColorBands: defaultBands,
                        detectedMarkerType: .labelDirection
                    )
                )
            }
            // Check for LEDs
            else if text.localizedCaseInsensitiveContains("LED") || text.localizedCaseInsensitiveContains("DIODE") {
                let fromPin = pinInfo?.pin ?? PinCoordinate(row: "12", column: "A")
                let toPin = PinCoordinate(row: "12", column: "B")
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: "part_led_red",
                        componentType: .led,
                        name: "Red LED",
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        fromPin: fromPin,
                        toPin: toPin,
                        detectedMarkerType: .anodeCathode
                    )
                )
            }
            // Check for Capacitors
            else if text.localizedCaseInsensitiveContains("CAP") || text.localizedCaseInsensitiveContains("100U") || text.localizedCaseInsensitiveContains("UF") {
                let fromPin = pinInfo?.pin ?? PinCoordinate(row: "2", column: "C")
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: "part_cap_100u",
                        componentType: .capacitorElectrolytic,
                        name: "100µF Capacitor",
                        confidence: max(0.65, conf),
                        cameraBoundingBox: box,
                        fromPin: fromPin,
                        toPin: nil,
                        detectedMarkerType: .polarityStripe
                    )
                )
            }
            // Check for ICs
            else if text.localizedCaseInsensitiveContains("IC") || text.localizedCaseInsensitiveContains("ATMEGA") || text.localizedCaseInsensitiveContains("555") {
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: "part_ic",
                        componentType: .integratedCircuit,
                        name: "Integrated Circuit",
                        confidence: max(0.75, conf),
                        cameraBoundingBox: box,
                        detectedMarkerType: .icNotch
                    )
                )
            }
        }
        
        // 2. Analyze detected geometric regions
        for region in observation.regions {
            let center = CGPoint(x: region.boundingBox.midX, y: region.boundingBox.midY)
            let pinInfo = calibration.flatMap { homographyService.mapCameraPointToPin(cameraPoint: center, calibration: $0) }
            
            // Check if this region wasn't already matched by an OCR component
            let overlapsExisting = detected.contains { d in
                d.cameraBoundingBox.intersects(region.boundingBox)
            }
            
            if !overlapsExisting {
                // Infer physical hardware or generic electronics component
                let labelLower = region.label.lowercased()
                let compType: ComponentType
                let name: String
                let partId: String?
                
                if labelLower.contains("dowel") {
                    compType = .dowel
                    name = "Wooden Dowel"
                    partId = "part_dowel_8mm"
                } else if labelLower.contains("cam") {
                    compType = .camLock
                    name = "Cam Lock"
                    partId = "part_cam_disc"
                } else if labelLower.contains("panel") || labelLower.contains("shelf") {
                    compType = .panel
                    name = "Panel Component"
                    partId = "part_side_panel"
                } else {
                    compType = .custom
                    name = region.label
                    partId = nil
                }
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: partId,
                        componentType: compType,
                        name: name,
                        confidence: Double(region.confidence),
                        cameraBoundingBox: region.boundingBox,
                        fromPin: pinInfo?.pin
                    )
                )
            }
        }
        
        return detected
    }
}
