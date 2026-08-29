//
//  AssemblyViewModel.swift
//  AssembleAI
//

import Foundation
import Combine
import UIKit

/// Verification execution mode selector.
enum VerificationMode: String, CaseIterable, Identifiable {
    case mock = "Mock Verification"
    case vision = "Vision Pipeline"
    case hybrid = "Hybrid Foundation"
    
    var id: String { rawValue }
}

/// High-level phase state driving the single task flow assembly experience.
enum AssemblyPhase: Equatable {
    case intro
    case instruction
    case camera
    case analyzing
    case visionDebug(VisualObservation)
    case verification(VerificationResult)
    case errorGuidance(VerificationResult)
    case stepCompleted(VerificationResult)
    case completed
}

/// Central state-driven View Model orchestrating physical assembly steps, camera triggers, Vision analysis, and visual guidance overlays.
@MainActor
final class AssemblyViewModel: ObservableObject {
    @Published var phase: AssemblyPhase = .intro
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var session: AssemblySession
    @Published var project: AssemblyProject
    @Published var capturedImage: UIImage? = nil
    @Published var latestObservation: VisualObservation? = nil
    @Published var activeGuidance: GuidanceOverlay? = nil
    @Published var verificationMode: VerificationMode = .hybrid
    @Published var showVisionDebugInDev: Bool = false
    
    private let verificationService: VerificationServiceProtocol
    private let visionAnalyzer: VisionAnalyzing
    private let guidanceProvider: GuidanceProviding
    
    init(
        project: AssemblyProject,
        verificationService: VerificationServiceProtocol = StateAwareVerificationService(),
        visionAnalyzer: VisionAnalyzing = VisionService(),
        guidanceProvider: GuidanceProviding = DefaultGuidanceProvider()
    ) {
        self.project = project
        self.verificationService = verificationService
        self.visionAnalyzer = visionAnalyzer
        self.guidanceProvider = guidanceProvider
        self.session = AssemblySession(projectId: project.id, currentStepIndex: project.completedSteps)
        self.currentStepIndex = max(0, min(project.completedSteps, max(0, project.steps.count - 1)))
    }
    
    /// Current assembly step or fallback step
    var currentStep: AssemblyStep {
        if currentStepIndex < project.steps.count {
            let summary = project.steps[currentStepIndex]
            return AssemblyStep(
                id: summary.id,
                projectId: project.id,
                stepOrder: summary.stepOrder,
                title: summary.title,
                instruction: summary.instruction
            )
        } else {
            return AssemblyStep(
                projectId: project.id,
                stepOrder: currentStepIndex + 1,
                title: "Step \(currentStepIndex + 1)",
                instruction: "Follow onscreen instructions."
            )
        }
    }
    
    /// Total number of steps in project
    var totalStepsCount: Int {
        max(1, project.totalSteps)
    }
    
    /// Step order label (1-indexed)
    var stepOrderLabel: Int {
        currentStepIndex + 1
    }
    
    // MARK: - Intent Actions
    
    func beginAssembly() {
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .instruction
        }
    }
    
    func openCamera() {
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .camera
        }
    }
    
    /// Captures camera frame, runs on-device Vision analysis to produce a VisualObservation, and evaluates verification.
    func triggerAnalysis(capturedImage: UIImage? = nil, viewSize: CGSize = CGSize(width: 390, height: 844)) {
        self.capturedImage = capturedImage
        self.session.attempts += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .analyzing
        }
        
        Task {
            // 1. Run Vision Analysis
            let targetImage = capturedImage ?? createFallbackFrame()
            let observation: VisualObservation
            do {
                observation = try await visionAnalyzer.analyze(image: targetImage)
            } catch {
                observation = VisualObservation(
                    imageSize: targetImage.size,
                    detectedText: [],
                    regions: [],
                    processingTimeMs: 0.0
                )
            }
            
            self.latestObservation = observation
            
            // 2. Run Verification Engine
            let result: VerificationResult
            do {
                result = try await verificationService.verifyStep(currentStep, image: targetImage)
            } catch {
                result = VerificationResult(
                    status: .incorrect,
                    confidence: 0.0,
                    detectedDescription: "Frame processing error",
                    expectedDescription: currentStep.title,
                    explanation: "Could not process image frame. Please retry inspection."
                )
            }
            
            // 3. Generate Visual Guidance Overlay if incorrect
            let comparison = StateComparison(
                status: result.isCorrect ? .correct : (result.status == .uncertain ? .uncertain : .incorrect),
                confidence: result.confidence,
                issues: result.isCorrect ? [] : [
                    StateIssue(
                        type: result.detectedDescription.contains("5V") ? .wrongConnection : .wrongPosition,
                        title: result.status == .uncertain ? "Need a clearer view" : "Wrong position",
                        explanation: result.explanation
                    )
                ],
                matchedComponents: []
            )
            
            self.activeGuidance = await guidanceProvider.guidance(for: comparison, step: currentStep, viewSize: viewSize)
            
            // 4. Transition to Debug screen (if enabled in dev mode) or directly to Verification
            #if DEBUG
            if self.showVisionDebugInDev {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.phase = .visionDebug(observation)
                }
                return
            }
            #endif
            
            self.handleVerificationResult(result)
        }
    }
    
    /// Continues from development debug view to verification result.
    func proceedFromVisionDebug() {
        Task {
            let targetImage = capturedImage ?? createFallbackFrame()
            let result = (try? await verificationService.verifyStep(currentStep, image: targetImage)) ?? VerificationResult(
                status: .incorrect,
                confidence: 0.0,
                detectedDescription: "Analysis fallback",
                expectedDescription: currentStep.title,
                explanation: "Processing fallback."
            )
            handleVerificationResult(result)
        }
    }
    
    private func handleVerificationResult(_ result: VerificationResult) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if result.isCorrect {
                session.completedSteps.insert(currentStepIndex)
                activeGuidance = nil
                phase = .verification(result)
            } else {
                session.errors += 1
                phase = .verification(result)
            }
        }
    }
    
    func proceedFromVerification(result: VerificationResult) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if result.isCorrect {
                activeGuidance = nil
                phase = .stepCompleted(result)
            } else {
                phase = .errorGuidance(result)
            }
        }
    }
    
    func nextStep() {
        activeGuidance = nil
        if currentStepIndex + 1 < totalStepsCount {
            currentStepIndex += 1
            session.currentStepIndex = currentStepIndex
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .instruction
            }
        } else {
            session.endedAt = Date()
            withAnimation(.easeInOut(duration: 0.4)) {
                phase = .completed
            }
        }
    }
    
    func retryCurrentStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .camera
        }
    }
    
    private func createFallbackFrame() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
