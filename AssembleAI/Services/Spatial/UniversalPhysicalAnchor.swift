//
//  UniversalPhysicalAnchor.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Universal geometric and topological primitives representing any physical assembly relationship in space.
///
/// Rather than creating bespoke code for every consumer product, all physical assemblies
/// decompose into four mathematical primitives:
/// 1. **Grid Anchor**: Regular pitch coordinate arrays (breadboard 2.54mm, Lego 8mm, PCB headers).
/// 2. **Plane Anchor**: Planar surfaces, flush boundaries, and perpendicular 90° joints (furniture, enclosures).
/// 3. **Fastener Anchor**: Count and seating depth of mechanical fasteners (screws, dowels, bolts).
/// 4. **Connector Anchor**: Continuous paths between two terminal endpoints (wires, cables, hoses).
nonisolated enum UniversalPhysicalAnchor: Sendable, Equatable, Hashable {
    case grid(GridAnchorDefinition)
    case plane(PlaneAnchorDefinition)
    case fastener(FastenerAnchorDefinition)
    case connector(ConnectorAnchorDefinition)
}

// MARK: - 1. Grid Anchor Definition

/// Regular discrete pitch coordinate grid.
nonisolated struct GridAnchorDefinition: Sendable, Equatable, Hashable {
    let identifier: String
    /// Pitch between adjacent holes/studs in millimeters (e.g. 2.54mm for breadboards, 8.0mm for Lego).
    let pitchMm: Double
    let rows: Int
    let columns: [String]
    let hasCenterDivider: Bool
    let centerDividerWidthMm: Double
    
    init(
        identifier: String = "standard_grid",
        pitchMm: Double = 2.54,
        rows: Int = 30,
        columns: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
        hasCenterDivider: Bool = true,
        centerDividerWidthMm: Double = 7.62
    ) {
        self.identifier = identifier
        self.pitchMm = pitchMm
        self.rows = rows
        self.columns = columns
        self.hasCenterDivider = hasCenterDivider
        self.centerDividerWidthMm = centerDividerWidthMm
    }
    
    /// Standard electronics half-size breadboard preset (2.54mm pitch, 30 rows).
    static let standardBreadboard = GridAnchorDefinition(
        identifier: "breadboard_half",
        pitchMm: 2.54,
        rows: 30,
        columns: ["-", "+", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "+", "-"]
    )
    
    /// Full-size electronics breadboard preset (2.54mm pitch, 63 rows).
    static let fullBreadboard = GridAnchorDefinition(
        identifier: "breadboard_full",
        pitchMm: 2.54,
        rows: 63,
        columns: ["-", "+", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "+", "-"]
    )
    
    /// Standard Lego stud grid preset (8.0mm pitch).
    static let legoPlate = GridAnchorDefinition(
        identifier: "lego_stud_grid",
        pitchMm: 8.0,
        rows: 16,
        columns: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"],
        hasCenterDivider: false,
        centerDividerWidthMm: 0.0
    )
}

// MARK: - 2. Plane Anchor Definition

/// Planar surface, edge boundary, or angular joint.
nonisolated struct PlaneAnchorDefinition: Sendable, Equatable, Hashable {
    let surfaceId: String
    let description: String
    let targetPlaneBounds: CGRect?
    /// Required angle between planes in degrees (e.g. 90.0 for perpendicular joints, 180.0 for flush panels).
    let requiredAngleDegrees: Double?
    let toleranceDegrees: Double
    
    init(
        surfaceId: String,
        description: String,
        targetPlaneBounds: CGRect? = nil,
        requiredAngleDegrees: Double? = 90.0,
        toleranceDegrees: Double = 5.0
    ) {
        self.surfaceId = surfaceId
        self.description = description
        self.targetPlaneBounds = targetPlaneBounds
        self.requiredAngleDegrees = requiredAngleDegrees
        self.toleranceDegrees = toleranceDegrees
    }
}

// MARK: - 3. Fastener Anchor Definition

/// Mechanical fastener verification (count and seated state).
nonisolated struct FastenerAnchorDefinition: Sendable, Equatable, Hashable {
    enum FastenerType: String, Codable, Sendable {
        case screw
        case bolt
        case nut
        case dowel
        case camLock
        case rivet
        case clip
    }
    
    let fastenerType: FastenerType
    let requiredCount: Int
    let locationDescription: String
    let requiresFlushSeating: Bool
    
    init(
        fastenerType: FastenerType,
        requiredCount: Int,
        locationDescription: String,
        requiresFlushSeating: Bool = true
    ) {
        self.fastenerType = fastenerType
        self.requiredCount = max(1, requiredCount)
        self.locationDescription = locationDescription
        self.requiresFlushSeating = requiresFlushSeating
    }
}

// MARK: - 4. Connector Anchor Definition

/// Continuous path connecting two physical endpoints.
nonisolated struct ConnectorAnchorDefinition: Sendable, Equatable, Hashable {
    enum ConnectorMedium: String, Codable, Sendable {
        case electricalWire
        case ribbonCable
        case pipe
        case mechanicalLinkage
    }
    
    let fromNode: String
    let toNode: String
    let medium: ConnectorMedium
    let polaritySensitive: Bool
    
    init(
        fromNode: String,
        toNode: String,
        medium: ConnectorMedium = .electricalWire,
        polaritySensitive: Bool = false
    ) {
        self.fromNode = fromNode
        self.toNode = toNode
        self.medium = medium
        self.polaritySensitive = polaritySensitive
    }
}

// MARK: - VisualContract Integration

extension VisualContract {
    /// Synthesizes the set of universal physical anchors required to verify this assembly step.
    /// Canonicalizes circuits, furniture, engines, and aerospace assemblies into the 4 physical primitives.
    var universalAnchors: [UniversalPhysicalAnchor] {
        var anchors: [UniversalPhysicalAnchor] = []
        
        // 1. Grid Anchors (Breadboards, Lego plates, PCB headers - H-4)
        if !pinPlacements.isEmpty {
            let maxRow = pinPlacements.map(\.coordinate.row).max() ?? 30
            let gridDef = maxRow > 35 ? GridAnchorDefinition.fullBreadboard : GridAnchorDefinition.standardBreadboard
            anchors.append(.grid(gridDef))
        }
        
        // 2. Fastener & Plane Anchors (Furniture, mechanics, engines, rockets)
        for spatial in spatialPlacements {
            let partLower = spatial.partId.lowercased()
            
            if partLower.contains("dowel") {
                anchors.append(.fastener(
                    FastenerAnchorDefinition(
                        fastenerType: .dowel,
                        requiredCount: spatial.quantity,
                        locationDescription: spatial.locationDescription,
                        requiresFlushSeating: true
                    )
                ))
            } else if partLower.contains("cam") {
                anchors.append(.fastener(
                    FastenerAnchorDefinition(
                        fastenerType: .camLock,
                        requiredCount: spatial.quantity,
                        locationDescription: spatial.locationDescription,
                        requiresFlushSeating: true
                    )
                ))
            } else if partLower.contains("screw") || partLower.contains("bolt") || partLower.contains("nail") {
                anchors.append(.fastener(
                    FastenerAnchorDefinition(
                        fastenerType: partLower.contains("bolt") ? .bolt : .screw,
                        requiredCount: spatial.quantity,
                        locationDescription: spatial.locationDescription,
                        requiresFlushSeating: true
                    )
                ))
            } else {
                // Plane Anchor (Side panels, shelves, engine block deck, chassis plate)
                anchors.append(.plane(
                    PlaneAnchorDefinition(
                        surfaceId: spatial.partId,
                        description: spatial.locationDescription,
                        targetPlaneBounds: spatial.targetRegion,
                        requiredAngleDegrees: 90.0,
                        toleranceDegrees: 5.0
                    )
                ))
            }
        }
        
        // 3. Connector Anchors (Wires, cables, pipes, hoses)
        for conn in expectedConnections {
            let medium: ConnectorAnchorDefinition.ConnectorMedium
            let nodeLower = (conn.fromNode + " " + conn.toNode).lowercased()
            if nodeLower.contains("pipe") || nodeLower.contains("hose") || nodeLower.contains("fluid") {
                medium = .pipe
            } else if nodeLower.contains("ribbon") || nodeLower.contains("bus") {
                medium = .ribbonCable
            } else if nodeLower.contains("rod") || nodeLower.contains("link") {
                medium = .mechanicalLinkage
            } else {
                medium = .electricalWire
            }
            
            let isPolarity = orientationConstraints.contains { constraint in
                constraint.componentId.localizedCaseInsensitiveContains(conn.fromNode) ||
                constraint.componentId.localizedCaseInsensitiveContains(conn.toNode)
            } || nodeLower.contains("anode") || nodeLower.contains("cathode") || nodeLower.contains("led") || nodeLower.contains("diode") || nodeLower.contains("polar") || nodeLower.contains("vcc") || nodeLower.contains("gnd")
            
            anchors.append(.connector(
                ConnectorAnchorDefinition(
                    fromNode: conn.fromNode,
                    toNode: conn.toNode,
                    medium: medium,
                    polaritySensitive: isPolarity
                )
            ))
        }
        
        return anchors
    }
}
