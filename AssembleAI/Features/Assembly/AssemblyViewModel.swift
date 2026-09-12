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
import ImageIO
import SwiftData

enum VerificationMode: String, CaseIterable, Identifiable, Codable, Hashable, Equatable, Sendable {
    case hybrid = "State-Aware Hybrid"
    case vision = "Vision Direct"
    
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
    
    // Situational Awareness State
    @Published var handActivity: WorkbenchHandActivity = .clear
    private var stepStartTime: Date = Date()
    private var lastInterventionTime: Date = Date()
    private var hesitationTask: Task<Void, Never>?
    
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
        self.sessionRepository = sessionRepository ?? LocalFirstSessionRepository(
            modelContext: PersistenceController.shared.container.mainContext,
            supabaseService: AppConfig.isSupabaseConfigured ? SupabaseProjectService(supabaseManager: SupabaseManager.shared) : nil
        )
        
        let mainContext = PersistenceController.shared.container.mainContext
        let targetProjId = project.id
        let descriptor = FetchDescriptor<LocalAssemblySession>(
            predicate: #Predicate<LocalAssemblySession> { $0.projectId == targetProjId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let existingSessions = (try? mainContext.fetch(descriptor)) ?? []
        let existingActive = existingSessions.first(where: { $0.statusRaw != SessionStatus.completed.rawValue })
            ?? existingSessions.first
        
        if let existing = existingActive {
            var domainSession = existing.toDomainModel()
            domainSession.status = .inProgress
            domainSession.projectTitle = project.title
            domainSession.updatedAt = Date()
            self.session = domainSession
            let restoredIndex = max(0, min(domainSession.currentStepIndex, max(0, project.steps.count - 1)))
            self.currentStepIndex = restoredIndex
        } else {
            let initialStepIndex = max(0, min(project.completedSteps, max(0, project.steps.count - 1)))
            self.currentStepIndex = initialStepIndex
            self.session = AssemblySession(
                projectId: project.id,
                projectTitle: project.title,
                currentStepIndex: initialStepIndex,
                currentStepOrder: initialStepIndex + 1
            )
        }
        self.persistSessionState()
        
        // Pause any other active projects so only this project is currently in-progress
        Task { [sessionRepo = self.sessionRepository, projId = project.id] in
            try? await sessionRepo?.pauseOtherActiveSessions(except: projId)
        }
    }
    
    deinit {
        liveObservationTask?.cancel()
        voiceInputTask?.cancel()
        autoProgressTask?.cancel()
        hesitationTask?.cancel()
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
                visualContract: summary.visualContract,
                commonMistakes: summary.commonMistakes
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
    
    /// Viewport size resolved from active window scene to support iOS 26+ without relying on deprecated UIScreen.main.
    private var screenViewportSize: CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                return window.bounds.size
            }
        }
        return CGSize(width: 393, height: 852)
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
            NotificationCenter.default.post(name: NSNotification.Name("AssemblySessionUpdated"), object: nil)
        }
    }
    
    // MARK: - Live Tutor Pipeline Orchestration
    
    /// Connects camera frame stream to the end-to-end Live Tutor observation, verification, speech, auto-progression, and research logging loop.
    func startLiveTutor(frameStream: AsyncStream<CVPixelBuffer>) {
        guard liveTutorEnabled else { return }
        stopLiveTutor()
        
        liveStatus = isLivePaused ? .paused : .live
        logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
        startHesitationWatchdog(for: currentStep)
        
        liveObservationTask = Task { [weak self] in
            guard let self = self else { return }
            
            let sampledFrames = self.frameSampler.sample(stream: frameStream)
            for await frame in sampledFrames {
                if Task.isCancelled { break }
                if self.isLivePaused { continue }
                if self.transitioningStepID != nil { continue }
                
                // 0. Situational Awareness: Evaluate user's hand activity on the workpiece
                let activity = await self.observationCoordinator.evaluateHandActivity(in: frame)
                self.handActivity = activity
                if activity == .handsWorking && self.liveStatus != .listening && self.liveStatus != .speaking && !self.isLivePaused {
                    self.liveStatus = .handsWorking
                } else if activity != .handsWorking && self.liveStatus == .handsWorking {
                    self.liveStatus = .live
                }
                
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
                
                // Real-time dynamic overlay update in Live Tutor
                let liveComparison = StateComparison(
                    status: verification.isCorrect ? .correct : (verification.status == .uncertain ? .uncertain : .incorrect),
                    confidence: verification.confidence,
                    issues: verification.primaryIssue.map { [$0] } ?? [],
                    matchedComponents: []
                )
                let overlay = await self.guidanceProvider.guidance(for: liveComparison, step: activeStep, viewSize: self.screenViewportSize)
                self.activeGuidance = overlay
                
                // Log Verification Research Telemetry
                let verDurationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                let verType: ResearchEventType = verification.isCorrect ? .verificationCorrect : (verification.status == .uncertain ? .verificationUncertain : .verificationIncorrect)
                var verMeta: [String: String] = [:]
                if let issue = verification.primaryIssue {
                    verMeta["issue_type"] = issue.type.rawValue
                    verMeta["issue_title"] = issue.title
                    verMeta["issue_severity"] = issue.severity.rawValue
                    switch issue.type {
                    case .wrongPosition:
                        verMeta["error_class"] = "E_off"
                    case .unexpectedComponent, .missingComponent:
                        verMeta["error_class"] = "E_sub"
                    case .wrongConnection:
                        verMeta["error_class"] = "E_pol"
                    case .missingConnection, .uncertainDetection, .insufficientVisualEvidence:
                        verMeta["error_class"] = "E_seat"
                    }
                } else if verification.isCorrect {
                    verMeta["error_class"] = "Nominal"
                }
                self.logResearchEvent(verType, durationMs: verDurationMs, status: verification.status.rawValue, metadata: verMeta)
                
                // 3. Evaluate Assistant Intervention Policy with Situational Timing and Hand Awareness
                let timeSinceStart = Date().timeIntervalSince(self.stepStartTime)
                let timeSinceLastIntervention = Date().timeIntervalSince(self.lastInterventionTime)
                let context = TutorContext(
                    currentStep: activeStep,
                    sessionID: self.session.id,
                    timeSinceStepStartedSeconds: timeSinceStart,
                    timeSinceLastInterventionSeconds: timeSinceLastIntervention,
                    lastVerificationResult: verification,
                    handActivity: activity
                )
                let decision = self.interventionPolicy.evaluate(event: .verificationUpdated(result: verification), context: context)
                
                // 4. Handle Spoken Guidance & Automatic Step Progression
                if decision.shouldIntervene {
                    self.lastInterventionTime = Date()
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
        project.completedSteps = session.completedSteps.count
        project.isActive = session.status != .completed
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
                self.session.currentStepOrder = self.currentStepIndex + 1
                self.project.completedSteps = self.session.completedSteps.count
                self.project.isActive = true
                self.persistSessionState()
                self.transitioningStepID = nil
                
                await self.observationCoordinator.resetForStepChange()
                self.interventionPolicy.resetForStepChange()
                self.currentVerificationResult = nil
                
                let nextStep = self.currentStep
                self.logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(nextStep.stepOrder)"])
                self.startHesitationWatchdog(for: nextStep)
                
                let introText = "Next, Step \(nextStep.stepOrder): \(nextStep.title). \(nextStep.instruction)"
                let introResponse = TutorResponse(text: introText, priority: .normal, category: "instruction")
                self.currentTutorMessage = introResponse
                
                if self.liveStatus != .listening && !self.isLivePaused {
                    self.liveStatus = .speaking
                    self.lastInterventionTime = Date()
                    await self.voiceOutput.speak(introResponse)
                    if self.liveStatus == .speaking {
                        self.liveStatus = self.isLivePaused ? .paused : .live
                    }
                }
            } else {
                self.session.status = .completed
                self.session.endedAt = Date()
                self.project.completedSteps = self.totalStepsCount
                self.project.isActive = false
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
        hesitationTask?.cancel()
        hesitationTask = nil
        transitioningStepID = nil
        Task { [voiceOutput, voiceInput] in
            await voiceOutput.stop()
            await voiceInput.stopListening()
        }
    }
    
    /// Finishes the active session or marks early exit before dismissal to ensure telemetry is safely logged and synced.
    func finishOrCancelSession() {
        stopLiveTutor()
        if session.status != .completed {
            session.endedAt = Date()
            persistSessionState()
            logResearchEvent(.sessionCompleted, metadata: ["earlyExit": "true"])
        }
    }
    
    /// Toggles pause state of live tutor observation and speech.
    func toggleLivePause() {
        isLivePaused.toggle()
        liveStatus = isLivePaused ? .paused : .live
        logResearchEvent(isLivePaused ? .liveTutorPaused : .liveTutorResumed)
        if isLivePaused {
            if isListening {
                isListening = false
                voiceInputTask?.cancel()
                voiceInputTask = nil
                Task { [voiceInput] in
                    await voiceInput.stopListening()
                }
            }
            Task { [voiceOutput] in
                await voiceOutput.stop()
            }
        } else {
            // Resuming: cleanly reset coordinator stability and restart hesitation watchdog
            Task { [observationCoordinator] in
                await observationCoordinator.resetForStepChange()
            }
            startHesitationWatchdog(for: currentStep)
        }
    }
    
    /// Toggles microphone listening state for user voice questions.
    func toggleVoiceInput() {
        if isListening {
            isListening = false
            liveStatus = isLivePaused ? .paused : .live
            Task { [voiceInput] in
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
        
        Task { [weak self] in
            guard let self = self else { return }
            guard let targetImage = self.capturedImage else {
                let uncertainResult = VerificationResult(
                    status: .uncertain,
                    confidence: 0.0,
                    detectedDescription: "No camera image acquired.",
                    expectedDescription: self.currentStep.title,
                    explanation: "Camera frame could not be acquired. Please ensure camera permissions are enabled and aim at your workspace."
                )
                self.phase = .verification(uncertainResult)
                return
            }
            let observation: VisualObservation
            do {
                observation = try await visionAnalyzer.analyze(image: targetImage)
            } catch {
                observation = VisualObservation(
                    imageSize: targetImage.size,
                    detectedText: [DetectedText](),
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
            
            let resolvedIssue: StateIssue? = result.primaryIssue ?? (result.isCorrect ? nil : StateIssue(
                type: result.status == .uncertain ? .insufficientVisualEvidence : .wrongPosition,
                title: result.status == .uncertain ? "Need a clearer view" : "Placement Mismatch",
                explanation: result.explanation
            ))
            
            let verType: ResearchEventType = result.isCorrect ? .verificationCorrect : (result.status == .uncertain ? .verificationUncertain : .verificationIncorrect)
            var analysisMeta: [String: String] = ["attempt": "\(session.attempts)"]
            if let issue = resolvedIssue {
                analysisMeta["issue_type"] = issue.type.rawValue
                analysisMeta["issue_title"] = issue.title
                analysisMeta["issue_severity"] = issue.severity.rawValue
                switch issue.type {
                case .wrongPosition:
                    analysisMeta["error_class"] = "E_off"
                case .unexpectedComponent, .missingComponent:
                    analysisMeta["error_class"] = "E_sub"
                case .wrongConnection:
                    analysisMeta["error_class"] = "E_pol"
                case .missingConnection, .uncertainDetection, .insufficientVisualEvidence:
                    analysisMeta["error_class"] = "E_seat"
                }
            } else if result.isCorrect {
                analysisMeta["error_class"] = "Nominal"
            }
            self.logResearchEvent(verType, status: result.status.rawValue, metadata: analysisMeta)
            
            let comparison = StateComparison(
                status: result.isCorrect ? .correct : (result.status == .uncertain ? .uncertain : .incorrect),
                confidence: result.confidence,
                issues: resolvedIssue.map { [$0] } ?? [],
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
        Task { [weak self] in
            guard let self = self else { return }
            let targetImage = self.capturedImage ?? self.createFallbackFrame()
            let result = (try? await self.verificationService.verifyStep(self.currentStep, image: targetImage)) ?? VerificationResult(
                status: .incorrect,
                confidence: 0.0,
                detectedDescription: "Analysis fallback",
                expectedDescription: self.currentStep.title,
                explanation: "Processing fallback."
            )
            self.handleVerificationResult(result)
        }
    }
    
    private func createFallbackFrame() -> UIImage {
        let size = CGSize(width: 320, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func handleVerificationResult(_ result: VerificationResult) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if result.isCorrect {
                session.completedSteps.insert(currentStepIndex)
                session.currentStepOrder = currentStepIndex + 1
                project.completedSteps = session.completedSteps.count
                project.isActive = session.status != .completed
                persistSessionState()
                activeGuidance = nil
                logResearchEvent(.stepCompleted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
                phase = .verification(result)
            } else {
                session.errors += 1
                persistSessionState()
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
        Task { [observationCoordinator] in
            await observationCoordinator.resetForStepChange()
        }
        
        if currentStepIndex + 1 < totalStepsCount {
            currentStepIndex += 1
            session.currentStepIndex = currentStepIndex
            session.currentStepOrder = currentStepIndex + 1
            project.completedSteps = session.completedSteps.count
            project.isActive = true
            persistSessionState()
            logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(currentStep.stepOrder)"])
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .instruction
            }
        } else {
            session.status = .completed
            session.endedAt = Date()
            project.completedSteps = totalStepsCount
            project.isActive = false
            persistSessionState()
            logResearchEvent(.sessionCompleted)
            withAnimation(.easeInOut(duration: 0.4)) {
                phase = .completed
            }
        }
    }
    
    func retryCurrentStep() {
        stopLiveTutor()
        activeGuidance = nil
        currentTutorMessage = nil
        currentVerificationResult = nil
        liveUserTranscript = ""
        
        interventionPolicy.resetForStepChange()
        Task { [observationCoordinator] in
            await observationCoordinator.resetForStepChange()
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .camera
        }
    }
    
    /// Jumps directly to the selected step from the Steps Overview Sheet with full state and voice resynchronization.
    func jumpToStep(step: AssemblyStep) {
        stopLiveTutor()
        activeGuidance = nil
        currentTutorMessage = nil
        currentVerificationResult = nil
        liveUserTranscript = ""
        
        let targetIndex = max(0, min(totalStepsCount - 1, step.stepOrder - 1))
        currentStepIndex = targetIndex
        session.currentStepIndex = currentStepIndex
        session.currentStepOrder = currentStepIndex + 1
        persistSessionState()
        
        interventionPolicy.resetForStepChange()
        Task { [observationCoordinator] in
            await observationCoordinator.resetForStepChange()
        }
        
        logResearchEvent(.stepStarted, metadata: ["stepOrder": "\(currentStep.stepOrder)", "reason": "userJump"])
        startHesitationWatchdog(for: currentStep)
        
        let targetStep = currentStep
        let introText = "Switched to Step \(targetStep.stepOrder): \(targetStep.title). \(targetStep.instruction)"
        let introResponse = TutorResponse(text: introText, priority: .normal, category: "instruction")
        self.currentTutorMessage = introResponse
        
        Task { [weak self] in
            guard let self = self else { return }
            if self.liveStatus != .listening && !self.isLivePaused {
                self.liveStatus = .speaking
                self.lastInterventionTime = Date()
                await self.voiceOutput.speak(introResponse)
                if self.liveStatus == .speaking {
                    self.liveStatus = self.isLivePaused ? .paused : .live
                }
            }
        }
    }
    
    /// Proactively detects hesitation when user is stuck on a step for >20 seconds without hand manipulation.
    private func startHesitationWatchdog(for step: AssemblyStep) {
        hesitationTask?.cancel()
        stepStartTime = Date()
        
        hesitationTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled else { return }
            guard self.currentStep.id == step.id, !self.isLivePaused else { return }
            
            // If hands are actively working, do not interrupt
            guard self.handActivity != .handsWorking else { return }
            
            let timeSinceLast = Date().timeIntervalSince(self.lastInterventionTime)
            guard timeSinceLast >= 15.0 else { return }
            
            let context = TutorContext(
                currentStep: step,
                sessionID: self.session.id,
                timeSinceStepStartedSeconds: Date().timeIntervalSince(self.stepStartTime),
                timeSinceLastInterventionSeconds: timeSinceLast,
                lastVerificationResult: self.currentVerificationResult,
                handActivity: self.handActivity
            )
            
            let decision = self.interventionPolicy.evaluate(event: .hesitationDetected(step: step, seconds: 20.0), context: context)
            if decision.shouldIntervene {
                let assistantContext = AssistantContext(
                    currentStep: step,
                    sessionID: self.session.id,
                    verificationResult: self.currentVerificationResult
                )
                if let response = await self.conversationalTutor.generateResponse(for: decision, context: assistantContext) {
                    guard self.currentStep.id == step.id else { return }
                    self.currentTutorMessage = response
                    if self.liveStatus != .listening && !self.isLivePaused {
                        self.liveStatus = .speaking
                        self.lastInterventionTime = Date()
                        await self.voiceOutput.speak(response)
                        if self.liveStatus == .speaking {
                            self.liveStatus = self.isLivePaused ? .paused : .live
                        }
                    }
                }
            }
        }
    }
}

