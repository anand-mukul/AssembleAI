//
//  VerificationServiceProtocol.swift
//  AssembleAI
//

import Foundation
import UIKit

/// Outcome status for state-aware visual task verification.
enum VerificationStatus: String, Codable, Sendable {
    case correct
    case incorrect
    case uncertain
}

/// Structured result returned by a verification service after analyzing physical assembly image state.
struct VerificationResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let status: VerificationStatus
    let confidence: Double
    let detectedDescription: String
    let expectedDescription: String
    let explanation: String
    
    init(
        id: UUID = UUID(),
        status: VerificationStatus,
        confidence: Double,
        detectedDescription: String,
        expectedDescription: String,
        explanation: String
    ) {
        self.id = id
        self.status = status
        self.confidence = confidence
        self.detectedDescription = detectedDescription
        self.expectedDescription = expectedDescription
        self.explanation = explanation
    }
    
    var isCorrect: Bool {
        status == .correct
    }
}

/// Abstract verification service protocol.
/// Allows `MockVerificationService` to be seamlessly swapped with Core ML, Vision, or Apple Foundation Models without modifying any UI views.
protocol VerificationServiceProtocol: Sendable {
    /// Analyzes a captured frame against an assembly step contract.
    func verifyStep(_ step: AssemblyStep, image: UIImage?) async throws -> VerificationResult
}
