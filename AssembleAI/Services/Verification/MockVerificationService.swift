//
//  MockVerificationService.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Mock verification service for demonstration purposes.
/// Implements `VerificationServiceProtocol` so it can later be replaced with Vision / Core ML / Foundation Models without changing any UI code.
final class MockVerificationService: VerificationServiceProtocol {
    
    func verifyStep(_ step: AssemblyStep, image: UIImage?) async throws -> VerificationResult {
        // Simulated analysis processing delay (1.8 seconds)
        try await Task.sleep(nanoseconds: 1_800_000_000)
        
        switch step.stepOrder {
        case 1:
            return VerificationResult(
                status: .correct,
                confidence: 0.94,
                detectedDescription: "220Ω Resistor placed bridging Row 10 to Row 15",
                expectedDescription: "220Ω Resistor placed bridging Row 10 to Row 15",
                explanation: "The resistor is correctly positioned across the designated breadboard rows."
            )
            
        case 2:
            return VerificationResult(
                status: .incorrect,
                confidence: 0.48,
                detectedDescription: "Resistor detected bridging Row 10 to Row 14",
                expectedDescription: "220Ω Resistor placed bridging Row 10 to Row 15",
                explanation: "The resistor lead is inserted into Row 14 instead of Row 15. Shift the right lead one slot over."
            )
            
        case 3:
            return VerificationResult(
                status: .uncertain,
                confidence: 0.42,
                detectedDescription: "Low lighting or partial component occlusion in viewfinder area",
                expectedDescription: "Red LED connected observing positive anode polarity",
                explanation: "Visual evidence confidence (42%) is below the required threshold. Move closer and ensure your workspace is clearly illuminated."
            )
            
        case 4:
            return VerificationResult(
                status: .incorrect,
                confidence: 0.52,
                detectedDescription: "Jumper wire connected to 5V power rail",
                expectedDescription: "Jumper wire connected to GND ground rail",
                explanation: "The jumper wire is connected to the positive 5V rail instead of the negative GND ground rail."
            )
            
        case 5:
            return VerificationResult(
                status: .correct,
                confidence: 0.95,
                detectedDescription: "Signal wire connected to GND rail",
                expectedDescription: "Signal wire connected to GND rail",
                explanation: "Jumper wire securely connected to ground rail."
            )
            
        case 6:
            return VerificationResult(
                status: .correct,
                confidence: 0.95,
                detectedDescription: "Signal wire connected to pin R1",
                expectedDescription: "Signal wire connected to pin R1",
                explanation: "Jumper wire securely connected to pin header R1."
            )
            
        case 7:
            return VerificationResult(
                status: .correct,
                confidence: 0.91,
                detectedDescription: "Multimeter probe points aligned across resistor terminals",
                expectedDescription: "Voltage check across resistor terminals",
                explanation: "Circuit continuity and resistance verified."
            )
            
        case 8:
            return VerificationResult(
                status: .correct,
                confidence: 0.98,
                detectedDescription: "LED illuminated brightly with 5V power active",
                expectedDescription: "LED illuminated with positive power supply",
                explanation: "Assembly successfully completed and power state verified."
            )
            
        default:
            return VerificationResult(
                status: .correct,
                confidence: 0.90,
                detectedDescription: "Physical component placement matches expected state",
                expectedDescription: step.title,
                explanation: "All physical alignment markers match expected visual step specification."
            )
        }
    }
}
