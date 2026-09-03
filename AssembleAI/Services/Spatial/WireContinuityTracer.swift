//
//  WireContinuityTracer.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Wire insulation color classification.
nonisolated enum WireColor: String, CaseIterable, Codable, Sendable {
    case red = "red"
    case black = "black"
    case blue = "blue"
    case yellow = "yellow"
    case green = "green"
    case white = "white"
    case orange = "orange"
    case unknown = "unknown"
    
    /// Expected circuit purpose.
    var typicalFunction: String {
        switch self {
        case .red, .orange: return "Power (VCC / +5V)"
        case .black: return "Ground (GND)"
        case .blue, .yellow, .green, .white: return "Signal / Bus Interconnect"
        case .unknown: return "Interconnect"
        }
    }
}

/// Traced wire connection between two physical endpoints.
nonisolated struct TracedWire: Identifiable, Sendable, Equatable {
    let id: UUID
    let color: WireColor
    let fromPin: PinCoordinate
    let toPin: PinCoordinate
    let confidence: Double
    let pathPoints: [CGPoint]
    
    init(
        id: UUID = UUID(),
        color: WireColor,
        fromPin: PinCoordinate,
        toPin: PinCoordinate,
        confidence: Double = 0.90,
        pathPoints: [CGPoint] = []
    ) {
        self.id = id
        self.color = color
        self.fromPin = fromPin
        self.toPin = toPin
        self.confidence = confidence
        self.pathPoints = pathPoints
    }
    
    /// Whether both endpoints are on the exact same breadboard tie row and bank (short circuit danger).
    var isSelfShort: Bool {
        fromPin.row == toPin.row &&
        ((["A","B","C","D","E"].contains(fromPin.column) && ["A","B","C","D","E"].contains(toPin.column)) ||
         (["F","G","H","I","J"].contains(fromPin.column) && ["F","G","H","I","J"].contains(toPin.column)))
    }
}

/// Outcome of wire continuity evaluation against a target step connection.
nonisolated struct WireContinuityEvaluation: Sendable, Equatable {
    let isConnected: Bool
    let isReversedPolarity: Bool
    let isSelfShort: Bool
    let explanation: String
    let detectedWire: TracedWire?
}

/// Tracing and continuity verification engine for jumper wires and component leads.
nonisolated struct WireContinuityTracer: Sendable {
    
    /// Evaluates whether a set of traced wires satisfies an expected connection contract.
    static func evaluateConnection(
        expectedFrom: String,
        expectedTo: String,
        tracedWires: [TracedWire]
    ) -> WireContinuityEvaluation {
        // Clean expected node labels
        let expFrom = expectedFrom.lowercased().trimmingCharacters(in: .whitespaces)
        let expTo = expectedTo.lowercased().trimmingCharacters(in: .whitespaces)
        
        for wire in tracedWires {
            let wireFrom = wire.fromPin.label.lowercased()
            let wireTo = wire.toPin.label.lowercased()
            let wireFromRow = wire.fromPin.row.lowercased()
            let wireToRow = wire.toPin.row.lowercased()
            
            // Check for self short
            if wire.isSelfShort {
                return WireContinuityEvaluation(
                    isConnected: false,
                    isReversedPolarity: false,
                    isSelfShort: true,
                    explanation: "Both ends of wire are plugged into Row \(wire.fromPin.row) on the same side, creating a short circuit.",
                    detectedWire: wire
                )
            }
            
            // Direct or reverse pin match
            let directMatch = (wireFrom.contains(expFrom) || expFrom.contains(wireFrom) || wireFromRow.contains(expFrom) || expFrom.contains(wireFromRow)) &&
                              (wireTo.contains(expTo) || expTo.contains(wireTo) || wireToRow.contains(expTo) || expTo.contains(wireToRow))
            
            let reverseMatch = (wireFrom.contains(expTo) || expTo.contains(wireFrom) || wireFromRow.contains(expTo) || expTo.contains(wireFromRow)) &&
                               (wireTo.contains(expFrom) || expFrom.contains(wireTo) || wireToRow.contains(expFrom) || expFrom.contains(wireToRow))
            
            if directMatch || reverseMatch {
                // Polarity sanity check: if ground wire is on power rail or vice-versa
                let isGndWire = wire.color == .black
                let onVccRail = wireFrom.contains("vcc") || wireTo.contains("vcc") || wireFrom.contains("+") || wireTo.contains("+")
                if isGndWire && onVccRail && (expFrom.contains("gnd") || expTo.contains("gnd")) {
                    return WireContinuityEvaluation(
                        isConnected: false,
                        isReversedPolarity: true,
                        isSelfShort: false,
                        explanation: "Ground wire is connected to the positive (+) VCC rail instead of the ground (−) rail.",
                        detectedWire: wire
                    )
                }
                
                return WireContinuityEvaluation(
                    isConnected: true,
                    isReversedPolarity: false,
                    isSelfShort: false,
                    explanation: "Connection verified between \(wire.fromPin.label) and \(wire.toPin.label).",
                    detectedWire: wire
                )
            }
        }
        
        return WireContinuityEvaluation(
            isConnected: false,
            isReversedPolarity: false,
            isSelfShort: false,
            explanation: "Required connection between \(expectedFrom) and \(expectedTo) not detected.",
            detectedWire: nil
        )
    }
}
