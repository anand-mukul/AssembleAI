//
//  ResistorColorBandDecoder.swift
//  AssembleAI
//

import Foundation
import UIKit
import CoreGraphics

/// EIA-RS-279 standard electronic color code representation.
nonisolated enum ResistorBandColor: String, CaseIterable, Codable, Sendable {
    case black = "black"
    case brown = "brown"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case violet = "violet"
    case gray = "gray"
    case white = "white"
    case gold = "gold"
    case silver = "silver"
    
    /// Significant digit value (0–9) for the first two or three bands.
    var digitValue: Int? {
        switch self {
        case .black: return 0
        case .brown: return 1
        case .red: return 2
        case .orange: return 3
        case .yellow: return 4
        case .green: return 5
        case .blue: return 6
        case .violet: return 7
        case .gray: return 8
        case .white: return 9
        case .gold, .silver: return nil
        }
    }
    
    /// Multiplier factor ($10^n$).
    var multiplier: Double? {
        switch self {
        case .black: return 1.0
        case .brown: return 10.0
        case .red: return 100.0
        case .orange: return 1_000.0
        case .yellow: return 10_000.0
        case .green: return 100_000.0
        case .blue: return 1_000_000.0
        case .violet: return 10_000_000.0
        case .gray: return 100_000_000.0
        case .white: return 1_000_000_000.0
        case .gold: return 0.1
        case .silver: return 0.01
        }
    }
    
    /// Tolerance percentage (e.g. 5.0 for ±5%).
    var tolerancePercent: Double? {
        switch self {
        case .brown: return 1.0
        case .red: return 2.0
        case .green: return 0.5
        case .blue: return 0.25
        case .violet: return 0.1
        case .gray: return 0.05
        case .gold: return 5.0
        case .silver: return 10.0
        default: return nil
        }
    }
    
    /// Canonical RGB approximation for color distance matching.
    var referenceColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .black: return (0.10, 0.10, 0.10)
        case .brown: return (0.45, 0.25, 0.12)
        case .red: return (0.85, 0.15, 0.15)
        case .orange: return (0.95, 0.50, 0.10)
        case .yellow: return (0.95, 0.85, 0.15)
        case .green: return (0.15, 0.65, 0.25)
        case .blue: return (0.15, 0.35, 0.85)
        case .violet: return (0.55, 0.20, 0.75)
        case .gray: return (0.55, 0.55, 0.55)
        case .white: return (0.95, 0.95, 0.95)
        case .gold: return (0.80, 0.65, 0.25)
        case .silver: return (0.75, 0.75, 0.78)
        }
    }
    
    /// Classifies an RGB triplet into the closest matching resistor band color using Euclidean distance.
    static func classify(r: Double, g: Double, b: Double) -> ResistorBandColor {
        var closest = ResistorBandColor.black
        var minDistance = Double.greatestFiniteMagnitude
        
        for band in ResistorBandColor.allCases {
            let ref = band.referenceColor
            let dr = r - ref.r
            let dg = g - ref.g
            let db = b - ref.b
            let dist = sqrt(dr * dr + dg * dg + db * db)
            if dist < minDistance {
                minDistance = dist
                closest = band
            }
        }
        return closest
    }
}

/// Decoded resistor specification including nominal resistance and tolerance.
nonisolated struct DecodedResistor: Sendable, Equatable {
    let ohms: Double
    let tolerancePercent: Double
    let bands: [ResistorBandColor]
    let formattedValue: String
    
    init(ohms: Double, tolerancePercent: Double = 5.0, bands: [ResistorBandColor] = []) {
        self.ohms = ohms
        self.tolerancePercent = tolerancePercent
        self.bands = bands
        
        if ohms >= 1_000_000 {
            let val = ohms / 1_000_000.0
            self.formattedValue = val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))MΩ" : String(format: "%.1fMΩ", val)
        } else if ohms >= 1_000 {
            let val = ohms / 1_000.0
            self.formattedValue = val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))kΩ" : String(format: "%.1fkΩ", val)
        } else {
            self.formattedValue = ohms.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(ohms))Ω" : String(format: "%.1fΩ", ohms)
        }
    }
}

/// Algorithmic resistor color band decoder and physical attribute validator.
nonisolated struct ResistorColorBandDecoder: Sendable {
    
    /// Decodes an array of color band names (e.g. `["red", "red", "brown", "gold"]`) into a `DecodedResistor`.
    static func decode(bands: [String]) -> DecodedResistor? {
        let bandColors = bands.compactMap { ResistorBandColor(rawValue: $0.lowercased().trimmingCharacters(in: .whitespaces)) }
        guard bandColors.count >= 3 else { return nil }
        return decode(bandColors: bandColors)
    }
    
    /// Decodes an array of typed `ResistorBandColor` into a `DecodedResistor`.
    static func decode(bandColors: [ResistorBandColor]) -> DecodedResistor? {
        guard bandColors.count >= 3 else { return nil }
        
        if bandColors.count == 4 {
            // Standard 4-band: Digit 1, Digit 2, Multiplier, Tolerance
            guard let d1 = bandColors[0].digitValue,
                  let d2 = bandColors[1].digitValue,
                  let mult = bandColors[2].multiplier else {
                return nil
            }
            let ohms = Double(d1 * 10 + d2) * mult
            let tol = bandColors[3].tolerancePercent ?? 5.0
            return DecodedResistor(ohms: ohms, tolerancePercent: tol, bands: bandColors)
            
        } else if bandColors.count == 5 {
            // Precision 5-band: Digit 1, Digit 2, Digit 3, Multiplier, Tolerance
            guard let d1 = bandColors[0].digitValue,
                  let d2 = bandColors[1].digitValue,
                  let d3 = bandColors[2].digitValue,
                  let mult = bandColors[3].multiplier else {
                return nil
            }
            let ohms = Double(d1 * 100 + d2 * 10 + d3) * mult
            let tol = bandColors[4].tolerancePercent ?? 1.0
            return DecodedResistor(ohms: ohms, tolerancePercent: tol, bands: bandColors)
            
        } else if bandColors.count == 3 {
            // 3-band (default 20% tolerance): Digit 1, Digit 2, Multiplier
            guard let d1 = bandColors[0].digitValue,
                  let d2 = bandColors[1].digitValue,
                  let mult = bandColors[2].multiplier else {
                return nil
            }
            let ohms = Double(d1 * 10 + d2) * mult
            return DecodedResistor(ohms: ohms, tolerancePercent: 20.0, bands: bandColors)
        }
        
        return nil
    }
    
    /// Parses a human-readable resistance string (e.g. "220Ω", "10k", "4.7kΩ", "1M") to nominal Ohms.
    static func parseNominalOhms(from text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "Ω", with: "")
            .replacingOccurrences(of: "ohm", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "ohms", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        
        if cleaned.lowercased().hasSuffix("m") {
            let numPart = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
            guard let val = Double(numPart) else { return nil }
            return val * 1_000_000.0
        } else if cleaned.lowercased().hasSuffix("k") {
            let numPart = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
            guard let val = Double(numPart) else { return nil }
            return val * 1_000.0
        } else {
            return Double(cleaned)
        }
    }
    
    /// Verifies if detected color bands match the expected physical attributes of a component requirement.
    static func matches(detectedBands: [String], expectedAttributes: ComponentPhysicalAttributes?) -> (matches: Bool, explanation: String) {
        guard let expected = expectedAttributes, let expBands = expected.colorBands, !expBands.isEmpty else {
            // No strict band expectation defined
            return (true, "No color band restrictions defined for this step.")
        }
        
        guard let detectedDecoded = decode(bands: detectedBands) else {
            return (false, "Could not decode detected color bands: \(detectedBands.joined(separator: "-")).")
        }
        
        if let expectedDecoded = decode(bands: expBands) {
            if abs(detectedDecoded.ohms - expectedDecoded.ohms) < 1e-3 {
                return (true, "Resistor value matches: \(detectedDecoded.formattedValue).")
            } else {
                return (
                    false,
                    "Detected \(detectedDecoded.formattedValue) (\(detectedBands.joined(separator: "-"))), but step requires \(expectedDecoded.formattedValue) (\(expBands.joined(separator: "-")))."
                )
            }
        }
        
        // Direct string array comparison fallback
        let cleanDetected = detectedBands.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let cleanExpected = expBands.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        
        if cleanDetected == cleanExpected {
            return (true, "Color bands match: \(detectedBands.joined(separator: "-")).")
        } else {
            return (false, "Color bands do not match: expected \(expBands.joined(separator: "-")), found \(detectedBands.joined(separator: "-")).")
        }
    }
}
