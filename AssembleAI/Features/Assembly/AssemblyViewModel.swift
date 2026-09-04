//
//  AssemblyViewModel.swift
//  AssembleAI
//

import Foundation
import Combine
import SwiftUI
import UIKit
import CoreVideo
import CoreMedia

/// Verification execution mode selector.
enum VerificationMode: String, CaseIterable, Identifiable, Codable, Hashable, Equatable, Sendable {
    case mock = "Mock Verification"
    case vision = "Vision Pipeline"
    case hybrid = "Hybrid Foundation"
    
    var id: String { rawValue }
}

/// High-level phase state driving the single task flow assembly experience.
enum AssemblyPhase: Equatable, Hashable, Sendable {
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

/// Central state-driven View Model orchestrating physical assembly steps, live vision observation, conversational tutor guidance, automatic step progression, and research instrumentation.
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
    
    // MARK: - Live Tutor HUD State (Phases 9-11)
    @Published var liveTutorEnabled: Bool = true
    @Published var isLivePaused: Bool = false
    @Published var liveStatus: LiveTutorStatus = .live
    @Published var currentTutorMessage: TutorResponse? = nil
    @Published var currentVerificationResult: VerificationResult? = nil
    @Published var isListening: Bool = false
    @Published var liveUserTranscript: String = ""
    
    // Double-Advancement & Stale Progression Guard
    private var transitioningStepID: UUID? = nil
    
    private let verificationService: VerificationServiceProtocol
    private let visionAnalyzer: VisionAnalyzing
    private let guidanceProvider: GuidanceProviding
    
    // Live Tutor Services
    private let frameSampler: FrameSamplingServiceProtocol
    private let observationCoordinator: LiveObservationCoordinating
    private let interventionPolicy: AssistantInterventionPolicing
    private let conversationalTutor: ConversationalTutorProviding
    private let voiceOutput: VoiceOutputServiceProtocol
    private let voiceInput: VoiceInputServiceProtocol
    private let intentParser: VoiceIntentParser
    private let researchLogger: ResearchLogging
    private let sessionRepository: SessionRepository?
    
    private var liveObservationTask: Task<Void, Never>?
    private var voiceInputTask: Task<Void, Never>?
    private var autoProgressTask: Task<Void, Never>?
    
    init(
        project: AssemblyProject,
        verificationService: VerificationServiceProtocol? = nil,
        visionAnalyzer: VisionAnalyzing? = nil,
        guidanceProvider: GuidanceProviding? = nil,
        frameSampler: FrameSamplingServiceProtocol? = nil,
        observationCoordinator: LiveObservationCoordinating? = nil,
        interventionPolicy: AssistantInterventionPolicing? = nil,
        conversationalTutor: ConversationalTutorProviding? = nil,
        voiceOutput: VoiceOutputServiceProtocol? = nil,
        voiceInput: VoiceInputServiceProtocol? = nil,
        researchLogger: ResearchLogging? = nil,
        sessionRepository: SessionRepository? = nil
    ) {
        self.project = project
        self.verificationService = verificationService ?? StateAwareVerificationService()
        self.visionAnalyzer = visionAnalyzer ?? VisionService()
        self.guidanceProvider = guidanceProvider ?? DefaultGuidanceProvider()
        self.frameSampler = frameSampler ?? FrameSamplingService()
        self.observationCoordinator = observationCoordinator ?? LiveObservationCoordinator()
        self.interventionPolicy = interventionPolicy ?? AssistantInterventionPolicy()
        self.conversationalTutor = conversationalTutor ?? HybridTutorResponseProvider()
        self.voiceOutput = voiceOutput ?? VoiceOutputService()
        self.voiceInput = voiceInput ?? VoiceInputService()
        self.intentParser = VoiceIntentParser()
        self.researchLogger = researchLogger ?? ResearchLogger.shared
        self.sessionRepository = sessionRepository ?? LocalFirstSessionRepository(modelContext: PersistenceController.shared.container.mainContext)
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
                instruction: summary.instruction,
                visualContract: summary.visualContract
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
    
    // MARK: - Telemetry Logging Helper
    
    private func logResearchEvent(_ type: ResearchEventType, durationMs: Int? = nil, status: String? = nil, metadata: [String: String] = [:]) {
        var enrichedMetadata = metadata
        if enrichedMetadata["strategy"] == nil {
            let strategy = UserDefaults.standard.string(forKey: "app_visual_history_strategy") ?? VisualHistoryStrategy.currentFrame.rawValue
            enrichedMetadata["strategy"] = strategy
        }
        let event = ResearchEvent(
            sessionID: session.id,
            projectID: project.id,
            stepID: currentStep.id,
            mode: liveTutorEnabled ? .liveTutor : .manual,
            eventType: type,
            durationMilliseconds: durationMs,
            verificationStatus: status,
            metadata: enrichedMetadata
        )
        Task { [weak self] in
            await self?.researchLogger.logEvent(event)
        }
    }
    
    // MARK: - Session Persistence Helper
    
    private func persistSessionState() {
        let currentSession = self.session
        Task { [weak self] in
            try? await self?.sessionRepository?.saveSession(currentSession)
        }
    }
    
    // MARK: - Live Tutor Pipeline Orchestration
    
    /// Connects camera frame stream to the end-to-end Live Tutor observation, verification, speech, auto-progression, and research logging loop.
    func startLiveTutor(frameStream: AsyncStream<CVPixelBuffer>) {
        guard liveTutorEnabled else { return }
        stopLiveTutor()
        
        liveStatus = isLivePaused ? .paused : .live
        logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
        
        liveObservationTask = Task { [weak self] in
            guard let self = self else { return }
            
            let sampledFrames = await self.frameSampler.sample(stream: frameStream)
            for await frame in sampledFrames {
                if Task.isCancelled { break }
                if self.isLivePaused { continue }
                
                let activeStep = self.currentStep
                let startTime = Date()
                
                // 1. Vision Analysis
                let frameTime = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
                guard let observation = try? await self.visionAnalyzer.analyze(frame: frame, orientation: .up, timestamp: frameTime) else {
                    continue
                }
                
                // 2. Coordinate Observation with State Estimation & Deterministic Verification
                guard let verification = await self.observationCoordinator.handleObservation(observation, for: activeStep) else {
                    continue
                }
                
                // Stale step check
                guard self.currentStep.id == activeStep.id else { continue }
                self.currentVerificationResult = verification
                
                // Log Verification Research Telemetry
                let verDurationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                let verType: ResearchEventType = verification.isCorrect ? .verificationCorrect : (verification.status == .uncertain ? .verificationUncertain : .verificationIncorrect)
                self.logResearchEvent(verType, durationMs: verDurationMs, status: verification.status.rawValue)
                
                // 3. Evaluate Assistant Intervention Policy
                let context = TutorContext(
                    currentStep: activeStep,
                    timeSinceStepStartedSeconds: 5.0,
                    lastVerificationResult: verification
                )
                let decision = self.interventionPolicy.evaluate(event: .verificationUpdated(result: verification), context: context)
                
                // 4. Handle Spoken Guidance & Automatic Step Progression
                if decision.shouldIntervene {
                    self.logResearchEvent(.interventionTriggered, metadata: ["reason": decision.reason])
                    
                    let assistantContext = AssistantContext(
                        currentStep: activeStep,
                        sessionID: self.session.id,
                        verificationResult: verification
                    )
                    
                    let modelStartTime = Date()
                    if let response = await self.conversationalTutor.generateResponse(for: decision, context: assistantContext) {
                        guard self.currentStep.id == activeStep.id else { continue }
                        let modelLatency = Int(Date().timeIntervalSince(modelStartTime) * 1000)
                        self.logResearchEvent(.assistantResponseGenerated, durationMs: modelLatency, metadata: ["category": response.category])
                        
                        self.currentTutorMessage = response
                        
                        if self.liveStatus != .listening {
                            self.liveStatus = .speaking
                            self.logResearchEvent(.assistantSpeechStarted)
                            await self.voiceOutput.speak(response)
                            self.logResearchEvent(.assistantSpeechCompleted)
                            if self.liveStatus == .speaking {
                                self.liveStatus = self.isLivePaused ? .paused : .live
                            }
                        }
                    }
                    
                    // 5. Automatic Progression Trigger on Confirmed Completion
                    if case .confirm = decision.action, verification.isCorrect {
                        self.triggerAutomaticStepProgression(for: activeStep)
                    }
                } else {
                    self.logResearchEvent(.interventionSuppressed, metadata: ["reason": decision.reason])
                }
            }
        }
    }
    
    /// Executes atomic, debounced progression to the next step or assembly completion.
    private func triggerAutomaticStepProgression(for completedStep: AssemblyStep) {
        guard liveTutorEnabled else { return }
        guard transitioningStepID != completedStep.id else { return }
        guard currentStep.id == completedStep.id else { return }
        
        transitioningStepID = completedStep.id
        session.completedSteps.insert(currentStepIndex)
        session.currentStepOrder = currentStepIndex + 1
        persistSessionState()
        logResearchEvent(.stepCompleted, metadata: ["stepOrder": "\(completedStep.stepOrder)"])
        
        autoProgressTask?.cancel()
        autoProgressTask = Task { [weak self] in
            guard let self = self else { return }
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled { return }
            
            if self.currentStepIndex + 1 < self.totalStepsCount {
                self.currentStepIndex += 1
                self.session.currentStepIndex = self.currentStepIndex
                self.transitioningStepID = nil
                
                await self.observationCoordinator.resetForStepChange()
                self.interventionPolicy.resetForStepChange()
                self.currentVerificationResult = nil
                
                let nextStep = self.currentStep
                self.logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(nextStep.stepOrder)"])
                
                let introText = "Next, Step \(nextStep.stepOrder): \(nextStep.title). \(nextStep.instruction)"
                let introResponse = TutorResponse(text: introText, priority: .normal, category: "instruction")
                self.currentTutorMessage = introResponse
                
                if self.liveStatus != .listening && !self.isLivePaused {
                    self.liveStatus = .speaking
                    await self.voiceOutput.speak(introResponse)
                    if self.liveStatus == .speaking {
                        self.liveStatus = self.isLivePaused ? .paused : .live
                    }
                }
            } else {
                self.session.status = .completed
                self.session.endedAt = Date()
                self.persistSessionState()
                self.transitioningStepID = nil
                self.stopLiveTutor()
                self.logResearchEvent(.sessionCompleted)
                
                let completionText = "Congratulations! You have successfully completed all assembly steps."
                let completionResponse = TutorResponse(text: completionText, priority: .high, category: "completion")
                await self.voiceOutput.speak(completionResponse)
                
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.phase = .completed
                }
            }
        }
    }
    
    /// Stops all live observation, speech generation, and voice input tasks.
    func stopLiveTutor() {
        liveObservationTask?.cancel()
        liveObservationTask = nil
        voiceInputTask?.cancel()
        voiceInputTask = nil
        autoProgressTask?.cancel()
        autoProgressTask = nil
        transitioningStepID = nil
        Task {
            await voiceOutput.stop()
            await voiceInput.stopListening()
        }
    }
    
    /// Toggles pause state of live tutor observation and speech.
    func toggleLivePause() {
        isLivePaused.toggle()
        liveStatus = isLivePaused ? .paused : .live
        logResearchEvent(isLivePaused ? .liveTutorPaused : .liveTutorResumed)
        if isLivePaused {
            Task {
                await voiceOutput.stop()
            }
        }
    }
    
    /// Toggles microphone listening state for user voice questions.
    func toggleVoiceInput() {
        if isListening {
            isListening = false
            liveStatus = isLivePaused ? .paused : .live
            Task {
                await voiceInput.stopListening()
            }
            voiceInputTask?.cancel()
            voiceInputTask = nil
        } else {
            isListening = true
            liveStatus = .listening
            liveUserTranscript = ""
            logResearchEvent(.userVoiceStarted)
            
            voiceInputTask = Task { [weak self] in
                guard let self = self else { return }
                await self.voiceOutput.stop()
                do {
                    try await self.voiceInput.startListening()
                    for await message in self.voiceInput.transcriptStream {
                        if Task.isCancelled { break }
                        self.liveUserTranscript = message.transcript
                        if message.isFinal {
                            let query = message.transcript
                            let intent = self.intentParser.parse(query)
                            self.isListening = false
                            self.liveStatus = .speaking
                            self.logResearchEvent(.userVoiceCompleted, metadata: ["intent": "\(intent)"])
                            
                            let response: TutorResponse
                            switch intent {
                            case .repeatInstruction:
                                response = TutorResponse(
                                    text: "Step \(self.currentStep.stepOrder): \(self.currentStep.title). \(self.currentStep.instruction)",
                                    priority: .immediate,
                                    category: "instruction"
                                )
                            case .askWhatNext:
                                if self.currentStepIndex < self.totalStepsCount {
                                    response = TutorResponse(
                                        text: "You are on Step \(self.currentStep.stepOrder): \(self.currentStep.title). \(self.currentStep.instruction)",
                                        priority: .immediate,
                                        category: "instruction"
                                    )
                                } else {
                                    response = TutorResponse(
                                        text: "The assembly is complete! Great work.",
                                        priority: .immediate,
                                        category: "completion"
                                    )
                                }
                            default:
                                let assistantContext = AssistantContext(
                                    currentStep: self.currentStep,
                                    sessionID: self.session.id,
                                    verificationResult: self.currentVerificationResult,
                                    userIntent: intent,
                                    userTranscript: query
                                )
                                response = await self.conversationalTutor.answerUserQuestion(
                                    query: query,
                                    intent: intent,
                                    context: assistantContext
                                )
                            }
                            
                            self.currentTutorMessage = response
                            self.logResearchEvent(.assistantSpeechStarted)
                            await self.voiceOutput.speak(response)
                            self.logResearchEvent(.assistantSpeechCompleted)
                            if self.liveStatus == .speaking {
                                self.liveStatus = self.isLivePaused ? .paused : .live
                            }
                            break
                        }
                    }
                } catch {
                    self.isListening = false
                    self.liveStatus = self.isLivePaused ? .paused : .live
                }
            }
        }
    }
    
    // MARK: - Legacy Manual Intent Actions
    
    func beginAssembly() {
        logResearchEvent(.sessionStarted)
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
        logResearchEvent(.manualAnalysisTriggered, metadata: ["attempt": "\(session.attempts)"])
        
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .analyzing
        }
        
        Task {
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
            
            let verType: ResearchEventType = result.isCorrect ? .verificationCorrect : (result.status == .uncertain ? .verificationUncertain : .verificationIncorrect)
            self.logResearchEvent(verType, status: result.status.rawValue)
            
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
                session.currentStepOrder = currentStepIndex + 1
                persistSessionState()
                activeGuidance = nil
                logResearchEvent(.stepCompleted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
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
        stopLiveTutor()
        activeGuidance = nil
        currentTutorMessage = nil
        currentVerificationResult = nil
        liveUserTranscript = ""
        
        interventionPolicy.resetForStepChange()
        Task {
            await observationCoordinator.resetForStepChange()
        }
        
        if currentStepIndex + 1 < totalStepsCount {
            currentStepIndex += 1
            session.currentStepIndex = currentStepIndex
            logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .instruction
            }
        } else {
            session.status = .completed
            session.endedAt = Date()
            persistSessionState()
            logResearchEvent(.sessionCompleted)
            withAnimation(.easeInOut(duration: 0.4)) {
                phase = .completed
            }
        }
    }
    
    func retryCurrentStep() {
        stopLiveTutor()
        currentTutorMessage = nil
        currentVerificationResult = nil
        liveUserTranscript = ""
        
        interventionPolicy.resetForStepChange()
        Task {
            await observationCoordinator.resetForStepChange()
        }
        
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
