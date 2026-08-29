//
//  ConversationalTutorProvider.swift
//  AssembleAI
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Conversation Message & Context

/// Short-term conversation turn in the active assembly session.
nonisolated struct ConversationMessage: Sendable, Equatable, Identifiable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let timestamp: Date
    
    nonisolated enum MessageSender: String, Sendable, Equatable {
        case user
        case assistant
    }
    
    nonisolated init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

/// Structured conversational and physical assembly context provided to Foundation Models.
nonisolated struct AssistantContext: Sendable {
    let currentStep: AssemblyStep
    let sessionID: UUID
    let expectedState: ExpectedAssemblyState?
    let observedState: ObservedAssemblyState?
    let verificationResult: VerificationResult?
    let primaryIssue: StateIssue?
    let userIntent: UserVoiceIntent?
    let userTranscript: String?
    let recentConversationHistory: [ConversationMessage]
    let attemptCount: Int
    
    nonisolated init(
        currentStep: AssemblyStep,
        sessionID: UUID = UUID(),
        expectedState: ExpectedAssemblyState? = nil,
        observedState: ObservedAssemblyState? = nil,
        verificationResult: VerificationResult? = nil,
        primaryIssue: StateIssue? = nil,
        userIntent: UserVoiceIntent? = nil,
        userTranscript: String? = nil,
        recentConversationHistory: [ConversationMessage] = [],
        attemptCount: Int = 1
    ) {
        self.currentStep = currentStep
        self.sessionID = sessionID
        self.expectedState = expectedState
        self.observedState = observedState
        self.verificationResult = verificationResult
        self.primaryIssue = primaryIssue
        self.userIntent = userIntent
        self.userTranscript = userTranscript
        self.recentConversationHistory = recentConversationHistory
        self.attemptCount = max(1, attemptCount)
    }
}

// MARK: - Conversational Tutor Protocol

/// Protocol for generating conversational, grounded tutor responses using Apple Foundation Models or local fallbacks.
protocol ConversationalTutorProviding: Sendable {
    /// Generates a spoken tutor response for an intervention decision and structured assistant context.
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse?
    
    /// Answers a direct user voice question using assembly context and bounded conversation memory.
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse
    
    /// Clears active conversational memory when session ends.
    func clearSessionContext() async
}

// MARK: - Foundation Models Tutor Response Provider

#if canImport(FoundationModels)
/// On-device Foundation Models conversational tutor using Apple's `FoundationModels` framework (`LanguageModelSession`).
///
/// HARD ARCHITECTURAL RULE:
/// The language model is used ONLY for generating natural-language explanations and spoken dialogue.
/// It NEVER decides correctness — correctness is determined deterministically by `AssemblyStateComparator`.
@available(iOS 26.0, *)
actor FoundationModelTutorResponseProvider: ConversationalTutorProviding {
    private let fallbackProvider = DeterministicTutorResponseProvider()
    private var sessionMemory: [UUID: [ConversationMessage]] = [:]
    
    init() {}
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        switch decision.action {
        case .remainSilent:
            return nil
            
        case .confirm(let step):
            // Generate friendly, varied completion praise
            let prompt = buildConfirmationPrompt(step: step, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                return TutorResponse(text: responseText, priority: .normal, category: "confirmation")
            }
            return fallbackProvider.response(for: decision)
            
        case .correct(let description, let level):
            // Generate grounded, concise error correction
            let prompt = buildCorrectionPrompt(description: description, level: level, context: context)
            let priority: ResponsePriority = (level == .detailed || level == .explicit) ? .high : .normal
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                return TutorResponse(text: responseText, priority: priority, category: "correction")
            }
            return fallbackProvider.response(for: decision)
            
        case .instruct(let step):
            let prompt = buildInstructionPrompt(step: step, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                return TutorResponse(text: responseText, priority: .normal, category: "instruction")
            }
            return fallbackProvider.response(for: decision)
            
        case .requestBetterView(let explanation):
            let prompt = buildCameraViewPrompt(explanation: explanation, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                return TutorResponse(text: responseText, priority: .normal, category: "camera_guidance")
            }
            return fallbackProvider.response(for: decision)
            
        case .offerHelp(let step, let attemptCount):
            let prompt = buildStuckPrompt(step: step, attemptCount: attemptCount, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                return TutorResponse(text: responseText, priority: .normal, category: "stuck_help")
            }
            return fallbackProvider.response(for: decision)
            
        case .respondToUser(let query):
            let intent = context.userIntent ?? .unknown(transcript: query)
            return await answerUserQuestion(query: query, intent: intent, context: context)
        }
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        recordTurn(sessionID: context.sessionID, userText: query)
        
        let prompt = buildUserQuestionPrompt(query: query, intent: intent, context: context)
        if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
            recordTurn(sessionID: context.sessionID, assistantText: responseText)
            return TutorResponse(text: responseText, priority: .immediate, category: "user_query_response")
        }
        
        // Fallback response
        let fallbackDecision = InterventionDecision(action: .respondToUser(query: query), reason: "Query")
        return fallbackProvider.response(for: fallbackDecision) ?? TutorResponse(
            text: "I'm focusing on step \(context.currentStep.stepOrder): \(context.currentStep.title).",
            priority: .immediate
        )
    }
    
    func clearSessionContext() {
        sessionMemory.removeAll()
    }
    
    // MARK: - Internal Model Invocation & Prompts
    
    private func queryLanguageModel(prompt: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }
    
    private func recordTurn(sessionID: UUID, userText: String? = nil, assistantText: String? = nil) {
        var turns = sessionMemory[sessionID] ?? []
        if let u = userText {
            turns.append(ConversationMessage(sender: .user, text: u))
        }
        if let a = assistantText {
            turns.append(ConversationMessage(sender: .assistant, text: a))
        }
        // Bound conversation memory to last 4 turns
        if turns.count > 4 {
            turns = Array(turns.suffix(4))
        }
        sessionMemory[sessionID] = turns
    }
    
    private func buildConfirmationPrompt(step: AssemblyStep, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, a calm, friendly, expert live assembly tutor.
        Produce a warm, concise 1-sentence spoken confirmation that step \(step.stepOrder) ("\(step.title)") is successfully verified.
        Do not use bullet points, markdown, or robot jargon.
        """
    }
    
    private func buildCorrectionPrompt(description: String, level: InterventionLevel, context: AssistantContext) -> String {
        let historyStr = formatRecentHistory(for: context.sessionID)
        return """
        SYSTEM: You are AssembleAI, a calm, friendly, expert live assembly tutor.
        The physical state comparator detected an issue: "\(description)".
        Current Step: \(context.currentStep.stepOrder) — \(context.currentStep.title).
        Escalation Level: \(level.rawValue).
        \(historyStr)
        
        INSTRUCTION: Explain the adjustment in 1-2 spoken sentences. Be concise and actionable.
        Never claim the circuit is correct when an issue is detected.
        """
    }
    
    private func buildInstructionPrompt(step: AssemblyStep, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, a calm, friendly, expert live assembly tutor.
        Introduce step \(step.stepOrder): "\(step.title)".
        Instruction: "\(step.instruction)".
        Deliver a concise 1-2 sentence spoken orientation.
        """
    }
    
    private func buildCameraViewPrompt(explanation: String, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI.
        Visual occlusion issue: "\(explanation)".
        Ask the user in 1 friendly sentence to move closer or improve lighting.
        """
    }
    
    private func buildStuckPrompt(step: AssemblyStep, attemptCount: Int, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI.
        The user has spent time on step \(step.stepOrder) ("\(step.title)").
        Offer gentle, friendly assistance in 1 sentence.
        """
    }
    
    private func buildUserQuestionPrompt(query: String, intent: UserVoiceIntent, context: AssistantContext) -> String {
        let historyStr = formatRecentHistory(for: context.sessionID)
        let expectedDesc = context.expectedState?.requiredComponents.map(\.name).joined(separator: ", ") ?? context.currentStep.title
        let issueDesc = context.primaryIssue?.explanation ?? (context.verificationResult?.explanation ?? "No active errors.")
        
        return """
        SYSTEM: You are AssembleAI, a live pair-programming and hardware tutor.
        Keep responses concise (1-2 sentences) and conversational for voice output.
        Grounded task facts:
        - Current Step: \(context.currentStep.stepOrder) (\(context.currentStep.title))
        - Instruction: \(context.currentStep.instruction)
        - Expected: \(expectedDesc)
        - Current State / Issue: \(issueDesc)
        - Intent: \(intent)
        \(historyStr)
        
        User question: "\(query)"
        Respond directly, accurately, and naturally.
        """
    }
    
    private func formatRecentHistory(for sessionID: UUID) -> String {
        guard let turns = sessionMemory[sessionID], !turns.isEmpty else { return "" }
        let formatted = turns.map { "\($0.sender == .user ? "User" : "Assistant"): \($0.text)" }.joined(separator: "\n")
        return "Recent Conversation:\n" + formatted
    }
}
#endif

// MARK: - Hybrid Conversational Tutor Provider

/// Hybrid conversational tutor provider routing requests to Apple Foundation Models when available,
/// with seamless automatic fallback to `DeterministicTutorResponseProvider`.
final class HybridTutorResponseProvider: ConversationalTutorProviding, @unchecked Sendable {
    private let fallbackProvider = DeterministicTutorResponseProvider()
    
    init() {}
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let provider = FoundationModelTutorResponseProvider()
            if let response = await provider.generateResponse(for: decision, context: context) {
                return response
            }
        }
        #endif
        
        return fallbackProvider.response(for: decision)
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let provider = FoundationModelTutorResponseProvider()
            return await provider.answerUserQuestion(query: query, intent: intent, context: context)
        }
        #endif
        
        let decision = InterventionDecision(action: .respondToUser(query: query), reason: "Query")
        return fallbackProvider.response(for: decision) ?? TutorResponse(
            text: "Regarding \(query): let's complete step \(context.currentStep.stepOrder) (\(context.currentStep.title)).",
            priority: .immediate
        )
    }
    
    func clearSessionContext() async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let provider = FoundationModelTutorResponseProvider()
            await provider.clearSessionContext()
        }
        #endif
    }
}

// MARK: - Mock Conversational Tutor Provider

/// Actor-isolated mock conversational tutor provider for unit testing with deterministic responses.
actor MockConversationalTutorProvider: ConversationalTutorProviding {
    private var scriptedResponses: [TutorResponse] = []
    private(set) var generateResponseCallCount: Int = 0
    private(set) var answerQuestionCallCount: Int = 0
    private(set) var lastReceivedContext: AssistantContext? = nil
    
    init(scriptedResponses: [TutorResponse] = []) {
        self.scriptedResponses = scriptedResponses
    }
    
    func setScriptedResponses(_ responses: [TutorResponse]) {
        self.scriptedResponses = responses
    }
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        generateResponseCallCount += 1
        lastReceivedContext = context
        
        guard decision.shouldIntervene else { return nil }
        
        if !scriptedResponses.isEmpty {
            return scriptedResponses.removeFirst()
        }
        
        let fallback = DeterministicTutorResponseProvider()
        return fallback.response(for: decision)
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        answerQuestionCallCount += 1
        lastReceivedContext = context
        
        if !scriptedResponses.isEmpty {
            return scriptedResponses.removeFirst()
        }
        
        switch intent {
        case .askWhy:
            return TutorResponse(text: "Row 15 connects to the power rail for this circuit.", priority: .immediate)
        case .askWhatNext:
            return TutorResponse(text: "Next, insert the red LED into node 12A.", priority: .immediate)
        case .repeatInstruction:
            return TutorResponse(text: "Step 1: Place the 220 ohm resistor between row 10 and row 15.", priority: .immediate)
        default:
            return TutorResponse(text: "Regarding \(query): follow the active blueprint slot.", priority: .immediate)
        }
    }
    
    func clearSessionContext() async {
        scriptedResponses.removeAll()
        lastReceivedContext = nil
    }
}
