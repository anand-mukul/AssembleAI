//
//  VoiceInputServiceProtocol.swift
//  AssembleAI
//

import Foundation

// MARK: - Voice Input State

/// Operational state of the speech recognition service.
enum VoiceInputState: String, Sendable, Equatable {
    /// Microphone is inactive.
    case idle
    /// Microphone is active and capturing audio buffers.
    case listening
    /// Finalizing or parsing speech recognition results.
    case processing
}

// MARK: - Voice Input Service Protocol

/// Abstract interface for voice input and speech recognition.
protocol VoiceInputServiceProtocol: Sendable {
    /// Current recognition operational state.
    var state: VoiceInputState { get async }
    
    /// Asynchronous stream yielding user speech messages (both partial and final).
    var transcriptStream: AsyncStream<UserVoiceMessage> { get }
    
    /// Asynchronously requests speech recognition authorization and begins audio engine capture.
    func startListening() async throws
    
    /// Stops audio capture and finalizes the active utterance.
    func stopListening() async
    
    /// Cancels active recognition without emitting a final transcript.
    func cancelListening() async
}
