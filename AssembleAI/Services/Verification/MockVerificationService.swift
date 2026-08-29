//
//  MockVerificationService.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Mock verification service for demonstration purposes.
/// Implements `VerificationServiceProtocol` so it can later be replaced with Core ML / Vision Models without changing any UI code.
final class MockVerificationService: VerificationServiceProtocol {
    
    func verifyStep(_ step: AssemblyStep, image: UIImage?) async throws -> VerificationResult {
        // Simulated analysis processing delay (1.2 seconds)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        
        switch step.stepOrder {
        case 1:
            return VerificationResult(
                status: .correct,
                confidence: 0.96,
                detectedDescription: "10K Ohm Resistor attached to R1 header pins",
                expectedDescription: "10K Ohm Resistor mounted at position R1",
                explanation: "Component leads are securely inserted into R1 slot with correct orientation."
            )
            
        case 2:
            return VerificationResult(
                status: .incorrect,
                confidence: 0.42,
                detectedDescription: "Empty R2 header slot detected (component missing)",
                expectedDescription: "100uF Electrolytic Capacitor mounted at C2 slot",
                explanation: "The C2 capacitor slot appears unpopulated. Insert the 100uF capacitor observing polarity indicators before proceeding."
            )
            
        case 3:
            return VerificationResult(
                status: .correct,
                confidence: 0.94,
                detectedDescription: "ATmega328P Microcontroller IC seated in DIP socket",
                expectedDescription: "ATmega328P IC inserted into 28-pin DIP socket",
                explanation: "IC notch alignment matches the pin 1 indicator on the PCB board."
            )
            
        default:
            return VerificationResult(
                status: .correct,
                confidence: 0.92,
                detectedDescription: "Physical component placement matches expected state",
                expectedDescription: step.title,
                explanation: "All physical alignment markers match expected visual step specification."
            )
        }
    }
}
