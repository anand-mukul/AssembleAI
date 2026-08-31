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
