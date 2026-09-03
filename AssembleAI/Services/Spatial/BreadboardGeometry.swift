//
//  BreadboardGeometry.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

/// Mathematical specification and coordinate mapping for standardized physical solderless breadboards.
///
/// Standard breadboards follow the 0.1-inch (2.54 mm) lead pitch convention:
/// - Columns A–E: Left terminal strip
/// - Center Divider / Trough: 7.62 mm (0.3 in / 3 pitches) isolation channel
/// - Columns F–J: Right terminal strip
/// - Power Distribution Rails: + (VCC) and − (GND) running vertically along borders
nonisolated struct BreadboardGeometry: Sendable, Equatable, Hashable {
    
    /// Standard breadboard format variants.
    enum Variant: String, Codable, Sendable, CaseIterable {
        /// Half-size breadboard (30 rows, 400 tie-points, ~85mm x 55mm).
        case halfSize = "half_size"
        /// Full-size breadboard (63 rows, 830 tie-points, ~165mm x 55mm).
        case fullSize = "full_size"
    }
    
    let variant: Variant
    let totalRows: Int
    
    /// Standard hole-to-hole pitch (2.54 mm / 0.1 in).
    static let pitchMm: Double = 2.54
    
    /// Center channel gap width between column E and column F (7.62 mm / 0.3 in).
    static let centerTroughMm: Double = 7.62
    
    /// Margin from breadboard outer edge to outer power rail.
    static let edgeMarginMm: Double = 4.0
    
    /// Distance between power rail lines (+ and -).
    static let railSpacingMm: Double = 2.54
    
    /// Distance from inner power rail to terminal strip column A / J.
    static let railToStripGapMm: Double = 3.81
    
    /// Physical width in millimeters (standard 55.0 mm).
    let widthMm: Double
    
    /// Physical length/height in millimeters along rows.
    let heightMm: Double
    
    init(variant: Variant = .halfSize) {
        self.variant = variant
        switch variant {
        case .halfSize:
            self.totalRows = 30
            self.widthMm = 55.0
            self.heightMm = 85.0
        case .fullSize:
            self.totalRows = 63
            self.widthMm = 55.0
            self.heightMm = 165.0
        }
    }
    
    // MARK: - Canonical Millimeter Coordinates
    
    /// Computes the exact physical millimeter position $(x, y)$ of a pin relative to top-left corner $(0, 0)$.
    ///
    /// $x$: lateral axis (Power - -> Power + -> Col A..E -> Trough -> Col F..J -> Power + -> Power -)
    /// $y$: longitudinal axis along row numbers (Row 1 at top, Row N at bottom)
    func millimeterPosition(for pin: PinCoordinate) -> CGPoint? {
        let yPos = rowYPositionMm(for: pin.row)
        guard let xPos = columnXPositionMm(for: pin.column, rowString: pin.row) else {
            return nil
        }
        return CGPoint(x: xPos, y: yPos)
    }
    
    /// Computes normalized coordinate $[0.0 \dots 1.0] \times [0.0 \dots 1.0]$ in rectified breadboard space.
    func normalizedPosition(for pin: PinCoordinate) -> CGPoint? {
        guard let mmPos = millimeterPosition(for: pin) else { return nil }
        return CGPoint(
            x: max(0.0, min(1.0, mmPos.x / widthMm)),
            y: max(0.0, min(1.0, mmPos.y / heightMm))
        )
    }
    
    // MARK: - Inverse Lookup (Point to Nearest Pin)
    
    /// Resolves the closest physical pin to a point in normalized rectified space $[0 \dots 1]$, along with distance in millimeters.
    func nearestPin(toNormalizedPoint point: CGPoint) -> (pin: PinCoordinate, distanceMm: Double)? {
        let mmX = point.x * widthMm
        let mmY = point.y * heightMm
        return nearestPin(toMillimeterPoint: CGPoint(x: mmX, y: mmY))
    }
    
    /// Resolves the closest physical pin to a point in millimeter space.
    func nearestPin(toMillimeterPoint point: CGPoint) -> (pin: PinCoordinate, distanceMm: Double)? {
        // Find closest row (1...totalRows)
        let rowPitch = Self.pitchMm
        let topMargin = (heightMm - Double(totalRows - 1) * rowPitch) / 2.0
        let rawRow = Int(round((point.y - topMargin) / rowPitch)) + 1
        let clampedRow = max(1, min(totalRows, rawRow))
        let rowStr = String(clampedRow)
        
        // Candidate columns: Left rails, A-E, F-J, Right rails
        let candidateColumns = ["-", "+", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "+", "-"]
        var closestPin = PinCoordinate(row: rowStr, column: "A")
        var minDistance = Double.greatestFiniteMagnitude
        
        for col in candidateColumns {
            let candidate = PinCoordinate(row: rowStr, column: col)
            guard let pos = millimeterPosition(for: candidate) else { continue }
            let dx = point.x - pos.x
            let dy = point.y - pos.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < minDistance {
                minDistance = dist
                closestPin = candidate
            }
        }
        
        return (pin: closestPin, distanceMm: minDistance)
    }
    
    // MARK: - Row & Slot Delta Calculations
    
    /// Computes discrete slot difference between two pin coordinates (e.g. Row 14 to Row 15 = +1 slot).
    static func rowDelta(from: PinCoordinate, to: PinCoordinate) -> Int? {
        guard let fromRow = Int(from.row), let toRow = Int(to.row) else { return nil }
        return toRow - fromRow
    }
    
    /// Generates human-friendly physical alignment instruction for a detected coordinate offset.
    static func alignmentGuidance(detected: PinCoordinate, expected: PinCoordinate) -> String {
        if detected == expected {
            return "Placed correctly in \(expected.label)."
        }
        
        if let delta = rowDelta(from: detected, to: expected) {
            if delta > 0 {
                let slotWord = delta == 1 ? "slot" : "slots"
                return "Shift lead \(delta) \(slotWord) down to Row \(expected.row)."
            } else if delta < 0 {
                let slotWord = abs(delta) == 1 ? "slot" : "slots"
                return "Shift lead \(abs(delta)) \(slotWord) up to Row \(expected.row)."
            }
        }
        
        if detected.column != expected.column {
            return "Move lead from column \(detected.column) to column \(expected.column) on Row \(expected.row)."
        }
        
        return "Move component lead to target pin \(expected.label)."
    }
    
    // MARK: - Private Position Helpers
    
    private func rowYPositionMm(for rowString: String) -> Double {
        if let rowNum = Int(rowString) {
            let clamped = max(1, min(totalRows, rowNum))
            let topMargin = (heightMm - Double(totalRows - 1) * Self.pitchMm) / 2.0
            return topMargin + Double(clamped - 1) * Self.pitchMm
        }
        // Fallback for special power rails: center of the board vertically
        return heightMm / 2.0
    }
    
    private func columnXPositionMm(for columnString: String, rowString: String) -> Double? {
        let col = columnString.uppercased()
        let midX = widthMm / 2.0
        let halfTrough = Self.centerTroughMm / 2.0
        
        switch col {
        // Left power rails
        case "-", "GND":
            return Self.edgeMarginMm
        case "+", "VCC", "5V", "3V3":
            return Self.edgeMarginMm + Self.railSpacingMm
            
        // Terminal Strip: Left Bank (A ... E)
        case "A": return midX - halfTrough - 4.0 * Self.pitchMm
        case "B": return midX - halfTrough - 3.0 * Self.pitchMm
        case "C": return midX - halfTrough - 2.0 * Self.pitchMm
        case "D": return midX - halfTrough - 1.0 * Self.pitchMm
        case "E": return midX - halfTrough
            
        // Terminal Strip: Right Bank (F ... J)
        case "F": return midX + halfTrough
        case "G": return midX + halfTrough + 1.0 * Self.pitchMm
        case "H": return midX + halfTrough + 2.0 * Self.pitchMm
        case "I": return midX + halfTrough + 3.0 * Self.pitchMm
        case "J": return midX + halfTrough + 4.0 * Self.pitchMm
            
        default:
            return nil
        }
    }
}
