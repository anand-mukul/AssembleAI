//
//  AssistantInterventionPolicy.swift
//  AssembleAI
//

import Foundation

// MARK: - Tutor Event Model

/// Semantic events evaluated by the assistant intervention policy.
nonisolated enum TutorEvent: Sendable, Equatable {
    /// A new assembly step has begun.
    case stepStarted(step: AssemblyStep)
    
    /// A live physical-state verification evaluation completed with a deterministic result.
    case verificationUpdated(result: VerificationResult)
    
    /// User has been inactive without state progression past the stuck detection threshold.
    case inactiveTimeout
    
    /// User explicitly asked a question or requested help.
    case userQuestion(text: String)
    
    /// The entire assembly project session completed.
    case sessionCompleted
}

// MARK: - Intervention Level & Action

/// Escalating intervention detail level for repeated mistakes.
nonisolated enum InterventionLevel: String, Sendable, Equatable, Codable {
    /// First mistake: concise reminder.
    case gentle
    /// Second mistake: explicit actionable instruction.
    case explicit
    /// Repeated mistakes (3+): detailed breakdown with step context.
    case detailed
}

/// The specific category of proactive intervention decided by the policy.
nonisolated enum InterventionAction: Sendable, Equatable {
    /// Remain silent; do not interrupt the user.
    case remainSilent
    
    /// Deliver initial orientation or instruction for the active step.
    case instruct(step: AssemblyStep)
    
    /// Confirm successful completion of the step.
    case confirm(step: AssemblyStep)
    
    /// Correct a physical error with escalating assistance level.
    case correct(description: String, level: InterventionLevel)
    
    /// Request the user adjust camera framing, distance, or lighting for a clearer view.
    case requestBetterView(explanation: String)
    
    /// Proactively offer help or a hint because the user appears stuck.
    case offerHelp(step: AssemblyStep, attemptCount: Int)
    
    /// Direct response to a user-initiated question.
    case respondToUser(query: String)
}

// MARK: - Intervention Decision

/// Structured outcome produced by the intervention policy determining whether to speak or remain silent.
nonisolated struct InterventionDecision: Sendable, Equatable {
    let action: InterventionAction
    let reason: String
    let timestamp: Date
    
    nonisolated init(
        action: InterventionAction,
        reason: String,
        timestamp: Date = Date()
    ) {
        self.action = action
        self.reason = reason
        self.timestamp = timestamp
    }
    
    /// Indicates whether the assistant should actively intervene rather than remaining silent.
    var shouldIntervene: Bool {
        if case .remainSilent = action {
            return false
        }
        return true
    }
    
    /// Indicates whether the intervention is an urgent correction.
    var isUrgent: Bool {
        if case .correct(_, let level) = action {
            return level == .explicit || level == .detailed
        }
        return false
    }
    
    /// Convenience static factory for silence.
    nonisolated static func silent(reason: String) -> InterventionDecision {
        InterventionDecision(action: .remainSilent, reason: reason)
    }
}

// MARK: - Tutor Context

/// Snapshot of current session, step, and timing context required for policy decisions.
nonisolated struct TutorContext: Sendable {
    let currentStep: AssemblyStep
    let sessionID: UUID
    let timeSinceStepStartedSeconds: Double
    let timeSinceLastInterventionSeconds: Double
    let lastVerificationResult: VerificationResult?
    let consecutiveMistakeCount: Int
    let consecutiveUncertainCount: Int
    let isStepCompleted: Bool
    
    nonisolated init(
        currentStep: AssemblyStep,
        sessionID: UUID = UUID(),
        timeSinceStepStartedSeconds: Double = 0.0,
        timeSinceLastInterventionSeconds: Double = Double.infinity,
        lastVerificationResult: VerificationResult? = nil,
        consecutiveMistakeCount: Int = 0,
        consecutiveUncertainCount: Int = 0,
        isStepCompleted: Bool = false
    ) {
        self.currentStep = currentStep
        self.sessionID = sessionID
        self.timeSinceStepStartedSeconds = max(0.0, timeSinceStepStartedSeconds)
        self.timeSinceLastInterventionSeconds = max(0.0, timeSinceLastInterventionSeconds)
        self.lastVerificationResult = lastVerificationResult
        self.consecutiveMistakeCount = max(0, consecutiveMistakeCount)
        self.consecutiveUncertainCount = max(0, consecutiveUncertainCount)
        self.isStepCompleted = isStepCompleted
    }
}

// MARK: - Intervention Policy Configuration

/// Configurable thresholds governing assistant cooldowns, stuck detection, and uncertainty sensitivity.
nonisolated struct InterventionPolicyConfiguration: Sendable, Equatable {
    /// Minimum time in seconds between consecutive proactive assistant interventions (default: 4.0s).
    var minimumCooldownSeconds: Double
    
    /// Minimum duration in seconds of inactivity without progression before triggering stuck detection (default: 15.0s).
    var stuckDetectionThresholdSeconds: Double
    
    /// Number of consecutive uncertain observations before requesting a better view (default: 3).
    var uncertainThresholdCount: Int
    
    /// Whether initial step instruction should be permitted upon step start (default: true).
    var allowInitialInstruction: Bool
    
    nonisolated init(
        minimumCooldownSeconds: Double = 4.0,
        stuckDetectionThresholdSeconds: Double = 15.0,
        uncertainThresholdCount: Int = 3,
        allowInitialInstruction: Bool = true
    ) {
        self.minimumCooldownSeconds = max(0.5, minimumCooldownSeconds)
        self.stuckDetectionThresholdSeconds = max(3.0, stuckDetectionThresholdSeconds)
        self.uncertainThresholdCount = max(1, uncertainThresholdCount)
        self.allowInitialInstruction = allowInitialInstruction
    }
    
    nonisolated static let `default` = InterventionPolicyConfiguration()
}

// MARK: - Assistant Intervention Policy Protocol

/// Deterministic behavioral policy protocol deciding when AssembleAI should intervene or remain silent.
protocol AssistantInterventionPolicing: Sendable {
    /// Evaluates a semantic tutor event against current assembly context.
    func evaluate(event: TutorEvent, context: TutorContext) -> InterventionDecision
    
    /// Resets all policy state for a new session.
    func reset()
    
    /// Resets step-specific cooldowns and mistake counters when transitioning steps.
    func resetForStepChange(newStep: AssemblyStep?)
}

extension AssistantInterventionPolicing {
    /// Convenience reset on step change.
    func resetForStepChange() {
        resetForStepChange(newStep: nil)
    }
}

// MARK: - Assistant Intervention Policy Implementation

/// Concrete deterministic intervention policy governing proactive spoken and visual assistant actions.
///
/// Ensures silence is a first-class decision, suppresses repeated spam, enforces cooldowns, and enables user overrides.
final class AssistantInterventionPolicy: AssistantInterventionPolicing, @unchecked Sendable {
    let configuration: InterventionPolicyConfiguration
    private let lock = NSLock()
    
    // Internal State Tracking
    private var activeStepID: UUID? = nil
    private var stepConfirmed: Bool = false
    private var consecutiveMistakes: Int = 0
    private var consecutiveUncertainties: Int = 0
    private var lastCorrectedExplanation: String? = nil
    private var lastInterventionTimestamp: Date? = nil
    
    init(configuration: InterventionPolicyConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Evaluation Engine
    
    func evaluate(event: TutorEvent, context: TutorContext) -> InterventionDecision {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Step Identity Check: Reset step state if step changed
        if activeStepID != context.currentStep.id {
            performStepReset(newStep: context.currentStep)
        }
        
        // 2. Priority 1: User-Initiated Question / Request for Help (Bypasses Cooldown)
        if case .userQuestion(let query) = event {
            recordIntervention()
            return InterventionDecision(
                action: .respondToUser(query: query),
                reason: "User explicitly requested assistance or asked a question."
            )
        }
        
        // 3. Priority 2: Step Started Event
        if case .stepStarted(let step) = event {
            if configuration.allowInitialInstruction {
                recordIntervention()
                return InterventionDecision(
                    action: .instruct(step: step),
                    reason: "Initial instruction for step start."
                )
            } else {
                return InterventionDecision.silent(reason: "Initial instruction disabled by configuration.")
            }
        }
        
        // 4. Session Completed Event
        if case .sessionCompleted = event {
            performFullReset()
            return InterventionDecision.silent(reason: "Assembly session completed.")
        }
        
        // 5. If current step is already verified as complete, remain silent
        if stepConfirmed || context.isStepCompleted {
            return InterventionDecision.silent(reason: "Step already confirmed complete.")
        }
        
        // 6. Priority 3: Verification Result Updates
        if case .verificationUpdated(let result) = event {
            return evaluateVerificationResult(result, context: context)
        }
        
        // 7. Priority 4: Stuck Detection / Inactivity Timeout
        if case .inactiveTimeout = event {
            return evaluateStuckTimeout(context: context)
        }
        
        // Default: Silence
        return InterventionDecision.silent(reason: "No actionable event triggers.")
    }
    
    // MARK: - Verification Evaluation
    
    private func evaluateVerificationResult(_ result: VerificationResult, context: TutorContext) -> InterventionDecision {
        switch result.status {
        case .correct:
            if stepConfirmed {
                return InterventionDecision.silent(reason: "Correct state already confirmed for this step.")
            }
            
            stepConfirmed = true
            consecutiveMistakes = 0
            consecutiveUncertainties = 0
            lastCorrectedExplanation = nil
            recordIntervention()
            
            return InterventionDecision(
                action: .confirm(step: context.currentStep),
                reason: "Physical state matches expected step contract."
            )
            
        case .incorrect:
            consecutiveMistakes += 1
            consecutiveUncertainties = 0
            
            // Check Cooldown
            if context.timeSinceLastInterventionSeconds < configuration.minimumCooldownSeconds {
                return InterventionDecision.silent(reason: "Intervention suppressed by cooldown period.")
            }
            
            // Duplicate Mistake Suppression (do not repeat identical correction if state hasn't changed)
            if let lastExpl = lastCorrectedExplanation, lastExpl == result.explanation,
               context.timeSinceLastInterventionSeconds < configuration.minimumCooldownSeconds * 2.0 {
                return InterventionDecision.silent(reason: "Identical mistake already corrected recently.")
            }
            
            // Determine Escalation Level
            let level: InterventionLevel
            if consecutiveMistakes <= 1 {
                level = .gentle
            } else if consecutiveMistakes == 2 {
                level = .explicit
            } else {
                level = .detailed
            }
            
            lastCorrectedExplanation = result.explanation
            recordIntervention()
            
            return InterventionDecision(
                action: .correct(description: result.explanation, level: level),
                reason: "Physical state discrepancy detected (Escalation level: \(level.rawValue))."
            )
            
        case .uncertain:
            consecutiveUncertainties += 1
            
            // Do not immediately complain about uncertainty — silence is first-class
            if consecutiveUncertainties < configuration.uncertainThresholdCount {
                return InterventionDecision.silent(reason: "Transient uncertainty — awaiting additional evidence.")
            }
            
            // Check Cooldown
            if context.timeSinceLastInterventionSeconds < configuration.minimumCooldownSeconds {
                return InterventionDecision.silent(reason: "Uncertainty prompt suppressed by cooldown.")
            }
            
            consecutiveUncertainties = 0 // Reset after triggering
            recordIntervention()
            
            return InterventionDecision(
                action: .requestBetterView(explanation: result.explanation),
                reason: "Persistent visual uncertainty requires improved camera framing or lighting."
            )
        }
    }
    
    // MARK: - Stuck Timeout Evaluation
    
    private func evaluateStuckTimeout(context: TutorContext) -> InterventionDecision {
        guard !stepConfirmed else {
            return InterventionDecision.silent(reason: "Step already confirmed.")
        }
        
        let isDurationStuck = context.timeSinceStepStartedSeconds >= configuration.stuckDetectionThresholdSeconds
        let isCooldownClear = context.timeSinceLastInterventionSeconds >= configuration.minimumCooldownSeconds
        
        if isDurationStuck && isCooldownClear {
            recordIntervention()
            return InterventionDecision(
                action: .offerHelp(step: context.currentStep, attemptCount: consecutiveMistakes),
                reason: "User has been working on step for \(Int(context.timeSinceStepStartedSeconds))s without completion."
            )
        } else {
            return InterventionDecision.silent(reason: "Stuck threshold not yet reached.")
        }
    }
    
    // MARK: - Lifecycle & State Resets
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        performFullReset()
    }
    
    func resetForStepChange(newStep: AssemblyStep? = nil) {
        lock.lock()
        defer { lock.unlock() }
        performStepReset(newStep: newStep)
    }
    
    private func performStepReset(newStep: AssemblyStep?) {
        activeStepID = newStep?.id
        stepConfirmed = false
        consecutiveMistakes = 0
        consecutiveUncertainties = 0
        lastCorrectedExplanation = nil
    }
    
    private func performFullReset() {
        activeStepID = nil
        stepConfirmed = false
        consecutiveMistakes = 0
        consecutiveUncertainties = 0
        lastCorrectedExplanation = nil
        lastInterventionTimestamp = nil
    }
    
    private func recordIntervention() {
        lastInterventionTimestamp = Date()
    }
}
