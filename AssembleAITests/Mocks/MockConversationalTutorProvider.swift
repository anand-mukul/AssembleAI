//
//  MockConversationalTutorProvider.swift
//  AssembleAITests
//

import Foundation
@testable import AssembleAI

/// Thread-safe mock conversational tutor provider for unit testing with deterministic responses.
final class MockConversationalTutorProvider: ConversationalTutorProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var scriptedResponses: [TutorResponse] = []
    private var _generateResponseCallCount: Int = 0
    private var _answerQuestionCallCount: Int = 0
    private var _lastReceivedContext: AssistantContext? = nil
    
    var generateResponseCallCount: Int {
        lock.withLock { _generateResponseCallCount }
    }
    
    var answerQuestionCallCount: Int {
        lock.withLock { _answerQuestionCallCount }
    }
    
    var lastReceivedContext: AssistantContext? {
        lock.withLock { _lastReceivedContext }
    }
    
    init(scriptedResponses: [TutorResponse] = []) {
        self.scriptedResponses = scriptedResponses
    }
    
    func setScriptedResponses(_ responses: [TutorResponse]) {
        lock.withLock {
            self.scriptedResponses = responses
        }
    }
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        let scripted: TutorResponse? = lock.withLock {
            _generateResponseCallCount += 1
            _lastReceivedContext = context
            return !scriptedResponses.isEmpty ? scriptedResponses.removeFirst() : nil
        }
        
        guard decision.shouldIntervene else { return nil }
        
        if let response = scripted {
            return response
        }
        
        let fallback = DeterministicTutorResponseProvider()
        return fallback.response(for: decision)
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        let scripted: TutorResponse? = lock.withLock {
            _answerQuestionCallCount += 1
            _lastReceivedContext = context
            return !scriptedResponses.isEmpty ? scriptedResponses.removeFirst() : nil
        }
        
        if let response = scripted {
            return response
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
        lock.withLock {
            scriptedResponses.removeAll()
            _lastReceivedContext = nil
        }
    }
    
    func generateStructuredFeedback(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> StructuredTutorFeedback {
        StructuredTutorFeedback(
            spokenMessage: "Mock Structured Feedback",
            targetHoleCoordinates: ["15E", "17E"],
            isUrgentCorrection: false,
            suggestedAction: "Proceed to next step",
            confidenceScore: 1.0
        )
    }
}
