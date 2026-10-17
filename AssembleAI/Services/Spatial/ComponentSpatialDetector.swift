//
//  ComponentSpatialDetector.swift
//  AssembleAI
//
//  Universal physical assembly perception engine.
//  Dynamically interprets visual observations across all physical assembly domains:
//  mechanical, furniture, 3D printers, robotics, plumbing, framing, tools, and electronics.
//

import Foundation
import CoreGraphics
import Vision
import UIKit

/// Result of spatial component detection in the camera frame across any physical assembly domain.
nonisolated struct SpatiallyDetectedComponent: Identifiable, Sendable, Equatable {
    let id: UUID
    let partId: String?
    let componentType: ComponentType
    let name: String
    let confidence: Double
    let cameraBoundingBox: CGRect
    
    // Universal physical and spatial coordinate bindings
    let spatialAnchorDescription: String?
    let universalAnchorType: String?
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
        spatialAnchorDescription: String? = nil,
        universalAnchorType: String? = nil,
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
        self.spatialAnchorDescription = spatialAnchorDescription
        self.universalAnchorType = universalAnchorType
        self.fromPin = fromPin
        self.toPin = toPin
        self.detectedColorBands = detectedColorBands
        self.detectedMarkerType = detectedMarkerType
        self.orientationDegrees = orientationDegrees
    }
}

/// Dynamic on-device spatial component detector interpreting visual observations, project BOM, and spatial coordinates.
nonisolated struct ComponentSpatialDetector: Sendable {
    
    private let homographyService: BreadboardHomographyService
    
    init(homographyService: BreadboardHomographyService = BreadboardHomographyService()) {
        self.homographyService = homographyService
    }
    
    /// Detects physical assembly components dynamically across mechanical, furniture, 3D printing,
    /// plumbing, robotics, framing, and circuit projects.
    ///
    /// - Parameters:
    ///   - observation: High-level fused Apple Vision observation (text, rectangles, taxonomies, humans).
    ///   - calibration: Optional planar or coordinate homography calibration.
    ///   - expectedComponents: Project Bill of Materials (BOM) for dynamic specification resolution.
    ///   - activeStep: Currently active assembly step for localized contract matching.
    /// - Returns: Array of typed spatial components detected in the workspace.
    func detectComponents(
        in observation: VisualObservation,
        calibration: BreadboardCalibration? = nil,
        expectedComponents: [ComponentRequirement] = [],
        activeStep: AssemblyStep? = nil
    ) -> [SpatiallyDetectedComponent] {
        var detected: [SpatiallyDetectedComponent] = []
        var matchedBOMPartIds = Set<String>()
        
        // MARK: - 1. Dynamic Text & Physical Specification Resolution
        for textObs in observation.detectedText {
            let text = textObs.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let conf = Double(textObs.confidence)
            let box = textObs.boundingBox
            let center = CGPoint(x: box.midX, y: box.midY)
            let pinInfo = calibration.flatMap { homographyService.mapCameraPointToPin(cameraPoint: center, calibration: $0) }
            
            // Priority 1: Check if text directly matches an expected component from the active project's BOM
            if let bomMatch = findMatchingBOM(forText: text, in: expectedComponents) {
                matchedBOMPartIds.insert(bomMatch.partId)
                let cType = inferComponentType(fromName: bomMatch.name, partId: bomMatch.partId)
                let colorBands = cType == .resistor ? extractDynamicColorBands(from: bomMatch.name) : []
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: bomMatch.partId,
                        componentType: cType,
                        name: bomMatch.name,
                        confidence: max(0.75, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "BOM Match: \(bomMatch.name)",
                        universalAnchorType: anchorType(for: cType),
                        fromPin: pinInfo?.pin,
                        toPin: nil,
                        detectedColorBands: colorBands,
                        detectedMarkerType: defaultMarkerType(for: cType)
                    )
                )
                continue
            }
            
            // Priority 2: Fasteners & Hardware (Bolts, Screws, Nuts, Dowels, Cam Locks, Rivets)
            if let fastInfo = parseFastenerSpec(from: text) {
                let dynamicPartId = "part_\(slug(fastInfo.name))"
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: fastInfo.type,
                        name: fastInfo.name,
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Fastener: \(fastInfo.size)",
                        universalAnchorType: "fastener",
                        fromPin: pinInfo?.pin
                    )
                )
            }
            // Priority 3: Structural Framing & Panels (Extrusions, Rails, Panels, Shelves, Brackets, Hinges)
            else if let structInfo = parseStructuralSpec(from: text) {
                let dynamicPartId = "part_\(slug(structInfo.name))"
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: structInfo.type,
                        name: structInfo.name,
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Structural Component",
                        universalAnchorType: "plane",
                        fromPin: pinInfo?.pin
                    )
                )
            }
            // Priority 4: Kinematic & Mechanical Motion (Bearings, Gears, Belts, Pulleys, Couplers, Motors)
            else if let mechInfo = parseMechanicalMotionSpec(from: text) {
                let dynamicPartId = "part_\(slug(mechInfo.name))"
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: mechInfo.type,
                        name: mechInfo.name,
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Mechanical Assembly Component",
                        universalAnchorType: "fastener",
                        fromPin: pinInfo?.pin
                    )
                )
            }
            // Priority 5: Plumbing, Piping & Fluidics (PVC, Copper, Tubing, Valves, Fittings)
            else if let plumbInfo = parsePlumbingSpec(from: text) {
                let dynamicPartId = "part_\(slug(plumbInfo.name))"
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: plumbInfo.type,
                        name: plumbInfo.name,
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Plumbing / Fluidic Component",
                        universalAnchorType: "connector",
                        fromPin: pinInfo?.pin
                    )
                )
            }
            // Priority 6: Assembly Tools & Instruments (Hex Keys, Screwdrivers, Wrenches, Calipers)
            else if let toolInfo = parseToolSpec(from: text) {
                let dynamicPartId = "part_\(slug(toolInfo.name))"
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: toolInfo.type,
                        name: toolInfo.name,
                        confidence: max(0.70, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Assembly Tool",
                        universalAnchorType: "tool",
                        fromPin: pinInfo?.pin
                    )
                )
            }
            // Priority 7: Electrical & Computing (Boards, ICs, Modules, Resistors, Capacitors, LEDs)
            else if let elecInfo = parseElectricalSpec(from: text) {
                let dynamicPartId = "part_\(slug(elecInfo.name))"
                let bands: [String] = {
                    guard elecInfo.type == .resistor, let val = elecInfo.value else { return [] }
                    return extractDynamicColorBands(from: val)
                }()
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: elecInfo.type,
                        name: elecInfo.name,
                        confidence: max(0.65, conf),
                        cameraBoundingBox: box,
                        spatialAnchorDescription: "Electrical Component",
                        universalAnchorType: "grid",
                        fromPin: pinInfo?.pin,
                        detectedColorBands: bands,
                        detectedMarkerType: defaultMarkerType(for: elecInfo.type)
                    )
                )
            }
            // Priority 8: Generic Part or Component Marking
            else if text.count >= 2 && !text.contains("=") && !text.contains("{") {
                let dynamicName = "Part (\(text.capitalized))"
                let dynamicPartId = "part_\(slug(text))"
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: dynamicPartId,
                        componentType: .custom,
                        name: dynamicName,
                        confidence: max(0.55, conf),
                        cameraBoundingBox: box,
                        fromPin: pinInfo?.pin
                    )
                )
            }
        }
        
        // MARK: - 2. Dynamic Region & Physical Geometry Analysis
        for (index, region) in observation.regions.enumerated() {
            let center = CGPoint(x: region.boundingBox.midX, y: region.boundingBox.midY)
            let pinInfo = calibration.flatMap { homographyService.mapCameraPointToPin(cameraPoint: center, calibration: $0) }
            
            // Check if region already overlaps an OCR-detected component
            let overlapsExisting = detected.contains { d in
                d.cameraBoundingBox.intersects(region.boundingBox)
            }
            guard !overlapsExisting else { continue }
            
            let labelLower = region.label.lowercased()
            let w = region.boundingBox.width
            let h = region.boundingBox.height
            let aspectRatio = max(w, h) / max(0.001, min(w, h))
            let area = w * h
            
            // Attempt matching with an unmatched BOM requirement (semantic text or physical geometry)
            var unmatchedBOM = expectedComponents.first { bom in
                !matchedBOMPartIds.contains(bom.partId) &&
                (labelLower.contains(bom.name.lowercased()) || bom.name.lowercased().contains(labelLower))
            }
            
            // Universal Physical Geometry Matcher:
            // Fasteners and physical parts have no OCR text, so correlate geometry with required BOM specs
            if unmatchedBOM == nil {
                unmatchedBOM = expectedComponents.first { bom in
                    guard !matchedBOMPartIds.contains(bom.partId) else { return false }
                    let bName = bom.name.lowercased()
                    let bPart = bom.partId.lowercased()
                    
                    // Large surface: panels, boards, shelves
                    if area >= 0.12 || max(w, h) >= 0.40 {
                        return bName.contains("panel") || bName.contains("shelf") || bName.contains("board") || bPart.contains("panel") || bPart.contains("shelf")
                    }
                    // Slender parts: dowels, bolts, screws, rails, wires
                    if aspectRatio >= 2.2 && area <= 0.12 {
                        return bName.contains("dowel") || bName.contains("bolt") || bName.contains("screw") || bName.contains("rod") || bName.contains("rail") || bName.contains("wire") || bPart.contains("dowel") || bPart.contains("bolt") || bPart.contains("screw")
                    }
                    // Compact small hardware: cam lock, nut, washer, rivet
                    if area <= 0.06 && aspectRatio <= 2.2 {
                        return bName.contains("cam") || bName.contains("nut") || bName.contains("disc") || bName.contains("washer") || bPart.contains("cam") || bPart.contains("nut")
                    }
                    return false
                }
            }
            
            if let bomMatch = unmatchedBOM {
                matchedBOMPartIds.insert(bomMatch.partId)
                let cType = inferComponentType(fromName: bomMatch.name, partId: bomMatch.partId)
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: bomMatch.partId,
                        componentType: cType,
                        name: bomMatch.name,
                        confidence: max(0.70, Double(region.confidence)),
                        cameraBoundingBox: region.boundingBox,
                        spatialAnchorDescription: "BOM Geometry Match",
                        universalAnchorType: anchorType(for: cType),
                        fromPin: pinInfo?.pin,
                        detectedMarkerType: defaultMarkerType(for: cType)
                    )
                )
                continue
            }
            
            // Dynamic physical geometry classification:
            let compType: ComponentType
            let name: String
            let partId: String
            let uAnchor: String
            
            if aspectRatio >= 3.0 {
                // Long slender extrusion, rod, pipe, rail, or wire
                compType = .rail
                name = "Extrusion / Rail / Rod"
                partId = "part_rail_\(region.id.uuidString.prefix(4).lowercased())"
                uAnchor = "plane"
            } else if area >= 0.12 || max(w, h) >= 0.45 {
                // Large planar surface: panel, shelf, board, or main workpiece
                compType = .panel
                name = "Workpiece / Structural Panel"
                partId = "part_panel_\(region.id.uuidString.prefix(4).lowercased())"
                uAnchor = "plane"
            } else if labelLower.contains("fastener") || labelLower.contains("screw") || labelLower.contains("bolt") {
                compType = .screw
                name = "Fastener / Screw"
                partId = "part_fastener_\(region.id.uuidString.prefix(4).lowercased())"
                uAnchor = "fastener"
            } else {
                compType = .custom
                name = "Physical Component #\(index + 1)"
                partId = "part_component_\(region.id.uuidString.prefix(4).lowercased())"
                uAnchor = "plane"
            }
            
            detected.append(
                SpatiallyDetectedComponent(
                    partId: partId,
                    componentType: compType,
                    name: name,
                    confidence: max(0.60, Double(region.confidence)),
                    cameraBoundingBox: region.boundingBox,
                    spatialAnchorDescription: "Detected Visual Region",
                    universalAnchorType: uAnchor,
                    fromPin: pinInfo?.pin
                )
            )
        }
        
        // MARK: - 3. Universal Apple Neural Engine Taxonomy Parsing (1,300+ classes)
        for classification in observation.classifications {
            guard classification.confidence >= 0.20 else { continue }
            let identifier = classification.identifier
            
            // Extract leaf taxonomy title (e.g. "home > tool > screwdriver" -> "Screwdriver")
            let leaf = extractTaxonomyLeaf(from: identifier)
            guard !leaf.isEmpty else { continue }
            
            // Match against expected BOM items
            let matchingBOM = expectedComponents.first { bom in
                let bName = bom.name.lowercased()
                let lLower = leaf.lowercased()
                return bName.contains(lLower) || lLower.contains(bName)
            }
            
            let partId: String
            let compName: String
            let compType: ComponentType
            
            if let bom = matchingBOM {
                matchedBOMPartIds.insert(bom.partId)
                partId = bom.partId
                compName = bom.name
                compType = inferComponentType(fromName: bom.name, partId: bom.partId)
            } else {
                partId = "part_\(slug(leaf))"
                compName = leaf
                compType = inferComponentTypeFromTaxonomy(identifier: identifier, leaf: leaf)
            }
            
            let alreadyDetected = detected.contains { $0.partId == partId || $0.name == compName }
            if !alreadyDetected {
                // Bind to the most geometrically compatible unassigned salient region detected by Apple Neural Engine
                let usedBoxes = Set(detected.map(\.cameraBoundingBox))
                let matchingRegion = findGeometricallyCompatibleRegion(for: compType, in: observation.regions, alreadyUsed: usedBoxes)
                let liveBoundingBox = matchingRegion?.boundingBox ?? CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.50)
                
                detected.append(
                    SpatiallyDetectedComponent(
                        partId: partId,
                        componentType: compType,
                        name: compName,
                        confidence: Double(classification.confidence),
                        cameraBoundingBox: liveBoundingBox,
                        spatialAnchorDescription: "Apple Vision Neural Taxonomy",
                        universalAnchorType: anchorType(for: compType)
                    )
                )
            }
        }
        
        // MARK: - 4. Human Assembler Hand Presence Detection
        for humanBox in observation.detectedHumans {
            detected.append(
                SpatiallyDetectedComponent(
                    partId: "part_assembler_hands",
                    componentType: .custom,
                    name: "User Hands",
                    confidence: 0.90,
                    cameraBoundingBox: humanBox,
                    spatialAnchorDescription: "Human Interaction Zone",
                    universalAnchorType: "assembler"
                )
            )
        }
        
        return detected
    }
    
    // MARK: - Universal Multi-Domain Parsing Helpers
    
    /// Finds a matching BOM component for a detected text string.
    func findMatchingBOM(forText text: String, in bom: [ComponentRequirement]) -> ComponentRequirement? {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        let tClean = t.replacingOccurrences(of: "part_", with: "").replacingOccurrences(of: "_", with: " ")
        return bom.first { req in
            let rName = req.name.lowercased()
            let rRawId = req.partId.lowercased()
            let rId = rRawId.replacingOccurrences(of: "part_", with: "").replacingOccurrences(of: "_", with: " ")
            return t == rName || t == rRawId || t == rId || tClean == rId ||
                   rRawId.contains(t) || t.contains(rRawId) ||
                   (t.count >= 3 && (rName.contains(t) || t.contains(rName))) ||
                   (tClean.count >= 3 && (rName.contains(tClean) || tClean.contains(rName))) ||
                   (rId.count >= 3 && (rId.contains(tClean) || tClean.contains(rId)))
        }
    }
    
    /// Parses fastener specifications (e.g. "M4x20 Bolt", "M3x12", "1/4-20", "Hex Nut", "Dowel 8mm", "Cam Lock").
    func parseFastenerSpec(from text: String) -> (name: String, type: ComponentType, size: String)? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Metric Bolts / Screws (e.g. "M3", "M4x20", "M5x30 Bolt", "M8 Hex Screw")
        let metricPattern = "\\b(m[0-9]+(?:\\.[0-9]+)?)(?:x([0-9]+(?:\\.[0-9]+)?))?\\b"
        if let regex = try? NSRegularExpression(pattern: metricPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) {
            let matchedSize = (lower as NSString).substring(with: match.range).uppercased()
            let isNut = lower.contains("nut")
            let isBolt = lower.contains("bolt") || lower.contains("hex")
            let type: ComponentType = isNut ? .nut : (isBolt ? .bolt : .screw)
            let descriptive = isNut ? "\(matchedSize) Nut" : (isBolt ? "\(matchedSize) Bolt" : "\(matchedSize) Screw")
            return (name: text.localizedCaseInsensitiveContains("bolt") || text.localizedCaseInsensitiveContains("screw") || text.localizedCaseInsensitiveContains("nut") ? text.capitalized : descriptive, type: type, size: matchedSize)
        }
        
        // Imperial Fasteners (e.g. "1/4-20", "10-32", "#6-32", "3/8-16")
        let imperialPattern = "\\b(1/4-20|10-32|#6-32|#8-32|3/8-16)\\b"
        if let regex = try? NSRegularExpression(pattern: imperialPattern, options: []),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) {
            let matchedSize = (lower as NSString).substring(with: match.range)
            let type: ComponentType = lower.contains("nut") ? .nut : .bolt
            return (name: "\(matchedSize) \(type == .nut ? "Nut" : "Bolt")", type: type, size: matchedSize)
        }
        
        // Nuts & Washers
        if lower.contains("nut") {
            let name = text.capitalized.contains("Nut") ? text.capitalized : "\(text.capitalized) Nut"
            return (name: name, type: .nut, size: "Standard Nut")
        }
        
        // Dowels, Wooden Pins, Pegs
        if lower.contains("dowel") || lower.contains("peg") || lower.contains("wood pin") {
            let name = text.capitalized.contains("Dowel") ? text.capitalized : "\(text.capitalized) Dowel"
            return (name: name, type: .dowel, size: "Dowel Pin")
        }
        
        // Cam Locks & Furniture Connectors
        if lower.contains("cam lock") || lower.contains("cam bolt") || lower.contains("cam disc") || lower.contains("minifix") {
            return (name: text.capitalized, type: .camLock, size: "Cam Fastener")
        }
        
        // Generic Screw or Bolt keyword
        if lower.contains("screw") || lower.contains("bolt") {
            let type: ComponentType = lower.contains("bolt") ? .bolt : .screw
            return (name: text.capitalized, type: type, size: "Fastener")
        }
        
        return nil
    }
    
    /// Parses structural framing and panels (e.g. "2020 Extrusion", "Side Panel A", "Linear Rail MGN12", "Corner Bracket", "Hinge").
    func parseStructuralSpec(from text: String) -> (name: String, type: ComponentType)? {
        let lower = text.lowercased()
        
        // Extrusions & Linear Rails
        if lower.contains("2020") || lower.contains("2040") || lower.contains("4040") ||
           lower.contains("extrusion") || lower.contains("v-slot") || lower.contains("t-slot") ||
           lower.contains("linear rail") || lower.contains("mgn") || lower.contains("lead screw") || lower.contains("rail") {
            return (name: text.capitalized, type: .rail)
        }
        
        // Panels, Shelves, Boards
        if lower.contains("panel") || lower.contains("shelf") || lower.contains("board") ||
           lower.contains("plank") || lower.contains("plate") || lower.contains("sheet") || lower.contains("glass bed") {
            let type: ComponentType = lower.contains("panel") ? .panel : (lower.contains("shelf") ? .shelf : .panel)
            return (name: text.capitalized, type: type)
        }
        
        // Brackets & Mounts
        if lower.contains("bracket") || lower.contains("gusset") || lower.contains("mount") {
            return (name: text.capitalized, type: .bracket)
        }
        
        // Hinges
        if lower.contains("hinge") {
            return (name: text.capitalized, type: .hinge)
        }
        
        return nil
    }
    
    /// Parses kinematic, motion, and mechanical components (e.g. "608ZZ Bearing", "GT2 Belt", "20T Pulley", "NEMA 17 Stepper", "Spur Gear").
    func parseMechanicalMotionSpec(from text: String) -> (name: String, type: ComponentType)? {
        let lower = text.lowercased()
        
        // Bearings (Ball, Linear, Flanged)
        if lower.contains("608zz") || lower.contains("625zz") || lower.contains("6200") ||
           lower.contains("lm8uu") || lower.contains("bearing") {
            let name = text.capitalized.contains("Bearing") ? text.capitalized : "\(text.capitalized) Bearing"
            return (name: name, type: .bearing)
        }
        
        // Gears, Belts, Pulleys
        if lower.contains("pulley") || lower.contains("gear") || lower.contains("sprocket") {
            return (name: text.capitalized, type: .gear)
        }
        if lower.contains("gt2") || lower.contains("timing belt") || lower.contains("belt") {
            return (name: text.capitalized, type: .belt)
        }
        
        // Motors & Actuators
        if lower.contains("nema") || lower.contains("stepper") || lower.contains("servo") ||
           lower.contains("motor") || lower.contains("actuator") {
            return (name: text.capitalized, type: .motor)
        }
        
        return nil
    }
    
    /// Parses plumbing, tubing, and fluidic specifications (e.g. "1/2\" PVC Pipe", "Bowden Tube", "Ball Valve", "Push-Fit PC4-M10").
    func parsePlumbingSpec(from text: String) -> (name: String, type: ComponentType)? {
        let lower = text.lowercased()
        
        if lower.contains("pipe") || lower.contains("tube") || lower.contains("tubing") ||
           lower.contains("hose") || lower.contains("pvc") || lower.contains("pex") || lower.contains("bowden") {
            return (name: text.capitalized, type: .pipe)
        }
        
        if lower.contains("valve") || lower.contains("fitting") || lower.contains("coupling") ||
           lower.contains("push-fit") || lower.contains("nozzle") || lower.contains("elbow") {
            return (name: text.capitalized, type: .connector)
        }
        
        return nil
    }
    
    /// Parses assembly tools and measurement instruments (e.g. "3mm Allen Key", "Phillips Screwdriver", "10mm Wrench", "Calipers").
    func parseToolSpec(from text: String) -> (name: String, type: ComponentType)? {
        let lower = text.lowercased()
        
        let toolKeywords = ["allen key", "hex key", "hex wrench", "screwdriver", "phillips", "torx",
                            "spanner", "wrench", "caliper", "calipers", "level", "pliers", "mallet", "hammer"]
        for kw in toolKeywords {
            if lower.contains(kw) {
                return (name: text.capitalized, type: .tool)
            }
        }
        
        return nil
    }
    
    /// Parses electrical and electronic components (e.g. "ESP32", "4.7kΩ Resistor", "100µF Capacitor", "LED", "Breadboard").
    func parseElectricalSpec(from text: String) -> (name: String, type: ComponentType, value: String?)? {
        let lower = text.lowercased()
        
        // Boards
        if lower.contains("arduino") || lower.contains("raspberry pi") || lower.contains("breadboard") ||
           lower.contains("pcb") || lower.contains("motherboard") {
            return (name: text.capitalized, type: .board, value: nil)
        }
        
        // ICs and Modules
        if let ic = parseIntegratedCircuitSpec(from: text) {
            return (name: "\(ic) IC / Module", type: .integratedCircuit, value: ic)
        }
        
        // Resistors
        if let res = parseResistorSpec(from: text) {
            return (name: "\(res.formattedOhms) Resistor", type: .resistor, value: res.formattedOhms)
        }
        
        // Capacitors
        if let cap = parseCapacitorSpec(from: text) {
            return (name: "\(cap.value) Capacitor", type: .capacitorElectrolytic, value: cap.value)
        }
        
        // LEDs & Diodes
        if lower.contains("led") || lower.contains("diode") {
            return (name: text.capitalized.contains("LED") ? text.capitalized : "\(text.capitalized) LED", type: .led, value: nil)
        }
        
        // Jumper Wires
        if lower.contains("jumper") || lower.contains("wire") || lower.contains("lead") {
            return (name: text.capitalized, type: .jumperWire, value: nil)
        }
        
        return nil
    }
    
    // MARK: - Legacy Compatible Parsers
    
    /// Dynamically parses a resistor specification (e.g. "220", "10K", "4.7k", "100kΩ", "1M", "330Ω").
    func parseResistorSpec(from text: String) -> (ohms: Double, formattedOhms: String)? {
        let lower = text.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Match numbers followed by multiplier or resistance identifier
        let regexPattern = "^(?:resistor|res|r)?([0-9]+(?:\\.[0-9]+)?)([kmr])?(?:ohm|ohms|ω|Ω)?(?:resistor|res|r)?$"
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) else {
            return nil
        }
        
        guard let numRange = Range(match.range(at: 1), in: lower),
              let val = Double(lower[numRange]) else { return nil }
        
        var multiplier: Double = 1.0
        var unitSuffix = "Ω"
        
        if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound, let unitRange = Range(match.range(at: 2), in: lower) {
            let unitStr = String(lower[unitRange]).lowercased()
            if unitStr == "k" {
                multiplier = 1_000.0
                unitSuffix = "kΩ"
            } else if unitStr == "m" {
                multiplier = 1_000_000.0
                unitSuffix = "MΩ"
            }
        }
        
        let ohms = val * multiplier
        let formattedVal = val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))\(unitSuffix)" : "\(val)\(unitSuffix)"
        return (ohms: ohms, formattedOhms: formattedVal)
    }
    
    /// Dynamically parses a capacitor specification (e.g. "100uF", "10µF", "22pF", "0.1uF", "47uF").
    func parseCapacitorSpec(from text: String) -> (value: String, isElectrolytic: Bool)? {
        let lower = text.lowercased()
        guard lower.contains("f") || lower.contains("cap") || lower.contains("100u") || lower.contains("10u") else { return nil }
        
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(u|µ|n|p|m)?f"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) {
            let matchedText = (lower as NSString).substring(with: match.range)
            let formatted = matchedText.uppercased().replacingOccurrences(of: "U", with: "µ")
            return (value: formatted, isElectrolytic: formatted.contains("µ") || formatted.contains("M"))
        }
        
        if lower.contains("cap") || lower.contains("capacitor") {
            return (value: "Capacitor", isElectrolytic: true)
        }
        
        return nil
    }
    
    /// Dynamically parses an integrated circuit, microcontroller, or module identifier (e.g. "NE555", "ATMEGA328P", "ESP32", "74HC595").
    func parseIntegratedCircuitSpec(from text: String) -> String? {
        let upper = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let pattern = "\\b(ATMEGA[0-9A-Z]*|ESP[0-9A-Z-]*|NE[0-9]{3}|LM[0-9]{3}|74HC[0-9]{3}|SN74[0-9A-Z]*|L298[A-Z]*|OLED[0-9.]*|DHT[0-9]*)\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: upper, options: [], range: NSRange(location: 0, length: upper.utf16.count)) {
            return (upper as NSString).substring(with: match.range)
        }
        
        if upper.hasPrefix("IC") || upper.hasPrefix("CHIP") {
            return upper
        }
        
        return nil
    }
    
    /// Dynamically parses mechanical fastener or structural specifications.
    func parseMechanicalSpec(from text: String) -> (name: String, type: ComponentType)? {
        if let fast = parseFastenerSpec(from: text) {
            return (name: fast.name, type: fast.type)
        }
        if let str = parseStructuralSpec(from: text) {
            return (name: str.name, type: str.type)
        }
        if let mech = parseMechanicalMotionSpec(from: text) {
            return (name: mech.name, type: mech.type)
        }
        return nil
    }
    
    /// Extracts leaf classification name from Apple Vision taxonomy identifier.
    func extractTaxonomyLeaf(from identifier: String) -> String {
        let components = identifier.components(separatedBy: CharacterSet(charactersIn: ">,/"))
        guard let last = components.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty else {
            return ""
        }
        
        return last
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    /// Infers ComponentType dynamically from Apple Neural Engine taxonomy identifier and leaf name.
    func inferComponentTypeFromTaxonomy(identifier: String, leaf: String) -> ComponentType {
        let combined = "\(identifier) \(leaf)".lowercased()
        
        // Fasteners & Hardware
        if combined.contains("screw") { return .screw }
        if combined.contains("bolt") { return .bolt }
        if combined.contains("nut") { return .nut }
        if combined.contains("bracket") { return .bracket }
        if combined.contains("dowel") { return .dowel }
        if combined.contains("hinge") { return .hinge }
        if combined.contains("rail") { return .rail }
        
        // Structural & Furniture
        if combined.contains("panel") || combined.contains("wood") || combined.contains("shelf") { return .panel }
        if combined.contains("shelf") { return .shelf }
        
        // Mechanical & Motion
        if combined.contains("bearing") { return .bearing }
        if combined.contains("gear") { return .gear }
        if combined.contains("belt") { return .belt }
        if combined.contains("motor") { return .motor }
        
        // Plumbing & Fluidics
        if combined.contains("pipe") || combined.contains("hose") || combined.contains("tube") { return .pipe }
        
        // Tools & Instruments
        if combined.contains("tool") || combined.contains("screwdriver") || combined.contains("wrench") ||
           combined.contains("hammer") || combined.contains("pliers") || combined.contains("pen") ||
           combined.contains("pencil") || combined.contains("marker") { return .tool }
        
        // Electronics
        if combined.contains("breadboard") || combined.contains("circuit board") || combined.contains("pcb") { return .board }
        if combined.contains("capacitor") { return .capacitorElectrolytic }
        if combined.contains("resistor") { return .resistor }
        if combined.contains("led") || combined.contains("diode") { return .led }
        if combined.contains("integrated circuit") || combined.contains("chip") { return .integratedCircuit }
        if combined.contains("wire") || combined.contains("cable") || combined.contains("cord") { return .jumperWire }
        if combined.contains("sensor") { return .sensor }
        
        return .custom
    }
    
    /// Infers ComponentType from a BOM component name and partId.
    func inferComponentType(fromName name: String, partId: String) -> ComponentType {
        let combined = "\(name) \(partId)".lowercased()
        
        // Fasteners
        if combined.contains("bolt") || combined.contains("_bolt_") { return .bolt }
        if combined.contains("screw") || combined.contains("_screw_") { return .screw }
        if combined.contains("nut") || combined.contains("_nut_") { return .nut }
        if combined.contains("dowel") || combined.contains("_dowel_") { return .dowel }
        if combined.contains("cam_lock") || combined.contains("cam lock") { return .camLock }
        
        // Structural
        if combined.contains("panel") || combined.contains("_panel_") { return .panel }
        if combined.contains("shelf") || combined.contains("_shelf_") { return .shelf }
        if combined.contains("bracket") || combined.contains("_bracket_") { return .bracket }
        if combined.contains("hinge") || combined.contains("_hinge_") { return .hinge }
        if combined.contains("rail") || combined.contains("extrusion") { return .rail }
        
        // Mechanical
        if combined.contains("bearing") { return .bearing }
        if combined.contains("gear") || combined.contains("pulley") { return .gear }
        if combined.contains("belt") { return .belt }
        if combined.contains("motor") || combined.contains("servo") { return .motor }
        
        // Plumbing
        if combined.contains("pipe") || combined.contains("hose") || combined.contains("tube") { return .pipe }
        
        // Tools
        if combined.contains("tool") || combined.contains("allen") || combined.contains("wrench") { return .tool }
        
        // Electronics
        if combined.contains("resistor") || combined.contains("_res_") { return .resistor }
        if combined.contains("capacitor") || combined.contains("_cap_") { return .capacitorElectrolytic }
        if combined.contains("led") || combined.contains("_led_") { return .led }
        if combined.contains("ic") || combined.contains("integrated_circuit") || combined.contains("chip") { return .integratedCircuit }
        if combined.contains("wire") || combined.contains("lead") || combined.contains("jumper") { return .jumperWire }
        if combined.contains("board") || combined.contains("breadboard") || combined.contains("pcb") { return .board }
        if combined.contains("sensor") { return .sensor }
        
        return .custom
    }
    
    /// Finds the most geometrically compatible unassigned salient region for a given component type.
    func findGeometricallyCompatibleRegion(
        for compType: ComponentType,
        in regions: [DetectedRegion],
        alreadyUsed: Set<CGRect>
    ) -> DetectedRegion? {
        let candidates = regions.filter { !alreadyUsed.contains($0.boundingBox) }
        guard !candidates.isEmpty else { return nil }
        
        switch compType {
        case .screw, .bolt, .nut, .camLock, .led, .capacitorCeramic:
            // Prefer compact hardware (area <= 0.08)
            return candidates.first { ($0.boundingBox.width * $0.boundingBox.height) <= 0.08 } ?? candidates.first
        case .panel, .shelf, .board:
            // Prefer large planar areas (area >= 0.15)
            return candidates.first { ($0.boundingBox.width * $0.boundingBox.height) >= 0.15 } ?? candidates.first
        case .tool, .dowel, .rail, .jumperWire, .pipe, .belt:
            // Prefer elongated / slender aspect ratios (aspect >= 2.0 or <= 0.5)
            return candidates.first {
                let h = max(0.001, $0.boundingBox.height)
                let aspect = $0.boundingBox.width / h
                return aspect >= 2.0 || aspect <= 0.5
            } ?? candidates.first
        default:
            return candidates.first
        }
    }
    
    /// Maps ComponentType to UniversalPhysicalAnchor string classification.
    func anchorType(for type: ComponentType) -> String {
        switch type {
        case .screw, .bolt, .nut, .dowel, .camLock, .bearing:
            return "fastener"
        case .panel, .shelf, .bracket, .hinge, .rail:
            return "plane"
        case .jumperWire, .pipe, .connector, .belt:
            return "connector"
        case .board, .resistor, .capacitor, .capacitorElectrolytic, .capacitorCeramic, .led, .integratedCircuit:
            return "grid"
        case .tool:
            return "tool"
        default:
            return "plane"
        }
    }
    
    /// Extracts dynamic resistor color bands from a BOM name (e.g. "10kΩ Resistor").
    func extractDynamicColorBands(from name: String) -> [String] {
        if let spec = parseResistorSpec(from: name) {
            return ResistorColorBandDecoder.bands(forOhms: spec.ohms)
        }
        return []
    }
    
    /// Default physical orientation marker type for a component class.
    func defaultMarkerType(for type: ComponentType) -> OrientationMarkerType {
        switch type {
        case .led:
            return .anodeCathode
        case .capacitorElectrolytic:
            return .polarityStripe
        case .integratedCircuit:
            return .icNotch
        case .resistor:
            return .labelDirection
        default:
            return .notApplicable
        }
    }
    
    /// Generates a standardized URL/identifier slug from an arbitrary title or spec string.
    func slug(_ string: String) -> String {
        string
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }
}

