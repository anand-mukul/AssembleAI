//
//  MockVoiceInputService.swift
//  AssembleAITests
//

import Foundation
@testable import AssembleAI

/// Actor-isolated mock speech recognition service for unit testing and deterministic simulation.
actor MockVoiceInputService: VoiceInputServiceProtocol {
    private var _state: VoiceInputState = .idle
    var state: VoiceInputState { _state }
    
    private let broadcaster = TranscriptStreamBroadcaster()
    
    init() {}
    
    nonisolated var transcriptStream: AsyncStream<UserVoiceMessage> {
        AsyncStream(UserVoiceMessage.self, bufferingPolicy: .bufferingNewest(10)) { continuation in
            let id = UUID()
            self.broadcaster.addContinuation(continuation, id: id)
            
            continuation.onTermination = { [weak self] _ in
                self?.broadcaster.removeContinuation(id: id)
            }
        }
    }
    
    func startListening() async throws {
        _state = .listening
    }
    
    func stopListening() async {
        _state = .idle
    }
    
    func cancelListening() async {
        _state = .idle
    }
    
    /// Injects a simulated spoken transcript for unit testing.
    func simulateSpokenTranscript(_ text: String, isFinal: Bool) {
        let message = UserVoiceMessage(transcript: text, isFinal: isFinal)
        if isFinal {
            _state = .idle
        }
        broadcaster.broadcast(message)
    }
}
