//
//  VisualContract.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

// MARK: - Pin Coordinate (Electronics Domain)

/// A specific pin position on a breadboard or PCB grid.
/// Standard breadboard conventions: Row 1–30, Column A–J, and power rails (+/−).
nonisolated struct PinCoordinate: Codable, Hashable, Equatable, Sendable {
    /// Row identifier (e.g., "10", "15", "GND", "VCC").
    let row: String
    
    /// Column identifier (e.g., "A", "E", "F", "+", "−").
    let column: String
    
    /// Combined human-readable label (e.g., "10E", "15F", "GND+").
    var label: String { "\(row)\(column)" }
    
    init(row: String, column: String) {
        self.row = row
        self.column = column
    }
    
    /// Convenience initializer parsing a combined pin string like "10E" or "GND+".
    init?(pinString: String) {
        let trimmed = pinString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // Special rail pins
        let railPrefixes = ["GND", "VCC", "5V", "3V3"]
        for prefix in railPrefixes {
            if trimmed.uppercased().hasPrefix(prefix) {
                self.row = prefix
                let suffix = String(trimmed.dropFirst(prefix.count))
                self.column = suffix.isEmpty ? "+" : suffix
                return
            }
        }
        
        // Standard pin: digits followed by letter(s)
        var rowPart = ""
        var colPart = ""
        for char in trimmed {
            if char.isNumber && colPart.isEmpty {
                rowPart.append(char)
            } else {
                colPart.append(char)
            }
        }
        
        guard !rowPart.isEmpty, !colPart.isEmpty else { return nil }
        self.row = rowPart
        self.column = colPart
    }
}

// MARK: - Component Physical Attributes

/// Physical characteristics of a component that enable on-device visual identification.
nonisolated struct ComponentPhysicalAttributes: Codable, Hashable, Equatable, Sendable {
    /// Resistor color band sequence (e.g., ["red", "red", "brown", "gold"] = 220Ω).
    let colorBands: [String]?
    
    /// Whether the component has directional polarity (LED anode/cathode, electrolytic capacitor).
    let polaritySensitive: Bool
    
    /// Orientation marker description (e.g., "notch faces left", "white stripe to GND rail").
    let orientationMarker: String?
    
    /// Physical package type (e.g., "DIP-8", "TO-92", "5mm", "axial").
    let packageType: String?
    
    /// Nominal electrical value (e.g., "220Ω", "100µF", "5mm red").
    let nominalValue: String?
    
    init(
        colorBands: [String]? = nil,
        polaritySensitive: Bool = false,
        orientationMarker: String? = nil,
        packageType: String? = nil,
        nominalValue: String? = nil
    ) {
        self.colorBands = colorBands
        self.polaritySensitive = polaritySensitive
        self.orientationMarker = orientationMarker
        self.packageType = packageType
        self.nominalValue = nominalValue
    }
}

// MARK: - Component Type Enumeration

/// Classification of physical components for Core ML detection model class mapping.
nonisolated enum ComponentType: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case resistor = "resistor"
    case capacitor = "capacitor"
    case capacitorElectrolytic = "capacitor_electrolytic"
    case capacitorCeramic = "capacitor_ceramic"
    case led = "led"
    case integratedCircuit = "integrated_circuit"
    case jumperWire = "jumper_wire"
    case connector = "connector"
    case sensor = "sensor"
    case motor = "motor"
    case potentiometer = "potentiometer"
    case transistor = "transistor"
    case diode = "diode"
    case crystal = "crystal"
    case board = "board"
    case custom = "custom"
    
    // Physical domain component types
    case screw = "screw"
    case bolt = "bolt"
    case nut = "nut"
    case bracket = "bracket"
    case panel = "panel"
    case shelf = "shelf"
    case dowel = "dowel"
    case camLock = "cam_lock"
    case hinge = "hinge"
    case rail = "rail"
    
    /// Whether this component type belongs to the electronics domain.
    var isElectronics: Bool {
        switch self {
        case .screw, .bolt, .nut, .bracket, .panel, .shelf, .dowel, .camLock, .hinge, .rail:
            return false
        default:
            return true
        }
    }
}

// MARK: - Target Placement (Electronics)

/// Exact physical placement target for an electronics component on a breadboard grid.
nonisolated struct PinPlacement: Codable, Hashable, Equatable, Sendable {
    /// Component part identifier (references BOM `partId`).
    let partId: String
    
    /// Starting pin coordinate (e.g., "10E").
    let fromPin: PinCoordinate
    
    /// Ending pin coordinate (e.g., "15F").
    let toPin: PinCoordinate
    
    /// Acceptable placement tolerance in millimeters (default: 2.5mm / 1 pin pitch).
    let toleranceMm: Double
    
    init(partId: String, fromPin: PinCoordinate, toPin: PinCoordinate, toleranceMm: Double = 2.5) {
        self.partId = partId
        self.fromPin = fromPin
        self.toPin = toPin
        self.toleranceMm = toleranceMm
    }
}

// MARK: - Spatial Placement (Physical Domain)

/// Spatial placement target for physical/mechanical assembly components.
nonisolated struct SpatialPlacement: Codable, Hashable, Equatable, Sendable {
    /// Component part identifier (references BOM `partId`).
    let partId: String
    
    /// Target location description (e.g., "left side panel, hole A3").
    let locationDescription: String
    
    /// Required orientation (e.g., "label facing outward", "threads pointing up").
    let orientation: String?
    
    /// Normalized bounding region within the camera frame [0.0–1.0].
    let targetRegion: CGRect?
    
    /// Number of units required at this location (e.g., 4 screws).
    let quantity: Int
    
    init(
        partId: String,
        locationDescription: String,
        orientation: String? = nil,
        targetRegion: CGRect? = nil,
        quantity: Int = 1
    ) {
        self.partId = partId
        self.locationDescription = locationDescription
        self.orientation = orientation
        self.targetRegion = targetRegion
        self.quantity = quantity
    }
}

// MARK: - Visual Contract

/// Machine-verifiable visual contract defining what a correctly completed step looks like.
/// The verification engine compares camera observations against this contract to determine pass/fail.
nonisolated struct VisualContract: Codable, Hashable, Equatable, Sendable {
    /// Component part IDs required to be visible in this step.
    let requiredComponentIds: [String]
    
    /// Electronics-domain pin placements (breadboard coordinates).
    let pinPlacements: [PinPlacement]
    
    /// Physical-domain spatial placements (furniture/mechanical positions).
    let spatialPlacements: [SpatialPlacement]
    
    /// Expected electrical connections between named nodes.
    let expectedConnections: [ConnectionContract]
    
    /// Polarity/orientation constraints (e.g., "cathode stripe faces GND rail").
    let orientationConstraints: [OrientationConstraint]
    
    /// Global placement tolerance override in millimeters.
    let toleranceMm: Double
    
    /// Dynamically maps internal BOM part IDs (e.g. "part_res_220", "part_cap_10u", "part_servo_sg90")
    /// to clean, human-readable display names, with pattern-based dynamic parsing for arbitrary new components.
    static func friendlyName(for partId: String, knownBOM: [String: String]? = nil) -> String {
        // 1. Direct BOM Registry Match (if provided by project metadata)
        if let directMatch = knownBOM?[partId], !directMatch.isEmpty {
            return directMatch
        }
        
        let trimmed = partId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Component" }
        
        // 2. Common Fast-Path Mappings
        switch trimmed {
        case "part_dowel_8mm": return "Wooden Dowel Pins"
        case "part_cam_bolt": return "Cam Lock Bolts"
        case "part_cam_disc": return "Cam Lock Discs"
        case "part_shelf": return "Shelf Board"
        case "part_side_panel": return "Side Panel"
        case "part_back_panel": return "HDF Back Panel"
        case "part_nail_15mm": return "15mm Panel Pins"
        case "part_breadboard": return "Breadboard"
        default: break
        }
        
        let lower = trimmed.lowercased()
        
        // 3. Dynamic Resistor Parsing (e.g. part_res_220 -> 220Ω Resistor, part_res_10k -> 10kΩ Resistor, part_res_4k7 -> 4.7kΩ Resistor)
        if lower.hasPrefix("part_res_") || lower.hasPrefix("res_") {
            var val = lower.replacingOccurrences(of: "part_res_", with: "").replacingOccurrences(of: "res_", with: "")
            if val.contains("k") {
                val = val.replacingOccurrences(of: "k", with: "kΩ")
            } else if val.contains("m") {
                val = val.replacingOccurrences(of: "m", with: "MΩ")
            }
            if !val.contains("Ω") {
                val = "\(val)Ω"
            }
            return "\(val) Resistor"
        }
        
        // 4. Dynamic Capacitor Parsing (e.g. part_cap_100u -> 100µF Capacitor, part_cap_22p -> 22pF Capacitor)
        if lower.hasPrefix("part_cap_") || lower.hasPrefix("cap_") {
            var val = lower.replacingOccurrences(of: "part_cap_", with: "").replacingOccurrences(of: "cap_", with: "")
            val = val.replacingOccurrences(of: "u", with: "µF")
            val = val.replacingOccurrences(of: "n", with: "nF")
            val = val.replacingOccurrences(of: "p", with: "pF")
            if !val.contains("F") {
                val = "\(val)µF"
            }
            return "\(val) Capacitor"
        }
        
        // 5. Dynamic LED Parsing (e.g. part_led_red -> Red LED, part_led_rgb -> RGB LED)
        if lower.hasPrefix("part_led_") || lower.hasPrefix("led_") {
            let color = lower.replacingOccurrences(of: "part_led_", with: "").replacingOccurrences(of: "led_", with: "")
            return "\(color.capitalized) LED"
        }
        
        // 6. Dynamic Wire Parsing (e.g. part_wire_black -> Black Jumper Wire)
        if lower.hasPrefix("part_wire_") || lower.hasPrefix("wire_") {
            let color = lower.replacingOccurrences(of: "part_wire_", with: "").replacingOccurrences(of: "wire_", with: "")
            return "\(color.capitalized) Jumper Wire"
        }
        
        // 7. Dynamic Screw / Fastener Parsing (e.g. part_screw_m3_10 -> M3 10mm Screw)
        if lower.hasPrefix("part_screw_") || lower.hasPrefix("screw_") {
            let spec = lower.replacingOccurrences(of: "part_screw_", with: "").replacingOccurrences(of: "screw_", with: "")
            let parts = spec.components(separatedBy: "_")
            if parts.count == 2 {
                return "\(parts[0].uppercased()) \(parts[1])mm Screw"
            }
            return "\(spec.replacingOccurrences(of: "_", with: " ").capitalized) Screw"
        }
        
        // 8. Universal Dynamic Fallback: Clean prefix, split underscores, and Title Case
        let cleaned = trimmed
            .replacingOccurrences(of: "part_", with: "")
            .replacingOccurrences(of: "comp_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        return cleaned.isEmpty ? "Component" : cleaned
    }
    
    init(
        requiredComponentIds: [String] = [],
        pinPlacements: [PinPlacement] = [],
        spatialPlacements: [SpatialPlacement] = [],
        expectedConnections: [ConnectionContract] = [],
        orientationConstraints: [OrientationConstraint] = [],
        toleranceMm: Double = 2.5
    ) {
        self.requiredComponentIds = requiredComponentIds
        self.pinPlacements = pinPlacements
        self.spatialPlacements = spatialPlacements
        self.expectedConnections = expectedConnections
        self.orientationConstraints = orientationConstraints
        self.toleranceMm = toleranceMm
    }
    
    /// Whether this contract contains any electronics-specific constraints.
    var hasElectronicsConstraints: Bool {
        !pinPlacements.isEmpty || !expectedConnections.isEmpty
    }
    
    /// Whether this contract contains any physical/spatial constraints.
    var hasSpatialConstraints: Bool {
        !spatialPlacements.isEmpty
    }
    
    /// Whether this contract contains physical assembly constraints (spatial placements).
    var hasPhysicalConstraints: Bool {
        hasSpatialConstraints
    }
}

// MARK: - Connection Contract

/// Expected electrical or mechanical connection between two named nodes.
nonisolated struct ConnectionContract: Codable, Hashable, Equatable, Sendable {
    /// Source node identifier (e.g., "resistor_220_lead_a", "VCC_rail", "panel_left_hole_3").
    let fromNode: String
    
    /// Destination node identifier.
    let toNode: String
    
    /// Connection type (e.g., "wire", "solder", "screw", "cam_lock").
    let connectionType: String
    
    init(fromNode: String, toNode: String, connectionType: String = "wire") {
        self.fromNode = fromNode
        self.toNode = toNode
        self.connectionType = connectionType
    }
}

// MARK: - Orientation Constraint

/// Physical orientation requirement for a directional component.
nonisolated struct OrientationConstraint: Codable, Hashable, Equatable, Sendable {
    /// Component part identifier.
    let partId: String
    
    /// Human-readable orientation rule (e.g., "Long lead (anode) faces Row 12A").
    let rule: String
    
    /// Machine-readable orientation marker type.
    let markerType: OrientationMarkerType
    
    /// Human-readable orientation rule description (alias for rule).
    var ruleDescription: String { rule }
    
    init(partId: String, rule: String, markerType: OrientationMarkerType = .notApplicable) {
        self.partId = partId
        self.rule = rule
        self.markerType = markerType
    }
}

/// Types of physical orientation markers detectable by vision.
nonisolated enum OrientationMarkerType: String, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case anodeCathode = "anode_cathode"
    case polarityStripe = "polarity_stripe"
    case icNotch = "ic_notch"
    case pin1Dot = "pin1_dot"
    case flatEdge = "flat_edge"
    case labelDirection = "label_direction"
    case notApplicable = "not_applicable"
}
