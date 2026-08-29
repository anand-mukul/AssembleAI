//
//  VoiceOutputServiceProtocol.swift
//  AssembleAI
//

import Foundation
import AVFoundation

// MARK: - Speech State

/// Operational state of the speech output service.
nonisolated enum SpeechState: String, Sendable, Equatable {
    /// No speech is currently playing.
    case idle
    /// Speech synthesizer is actively speaking an utterance.
    case speaking
    /// Speech playback is temporarily paused.
    case paused
}

// MARK: - Voice Output Configuration

/// Configuration controlling speech rate, pitch, volume, and language.
nonisolated struct VoiceOutputConfiguration: Sendable, Equatable {
    /// Speech rate (0.0 to 1.0; AVSpeechUtteranceDefaultSpeechRate is ~0.50).
    var rate: Float
    /// Speech pitch multiplier (0.5 to 2.0; default 1.0).
    var pitchMultiplier: Float
    /// Speech volume (0.0 to 1.0; default 1.0).
    var volume: Float
    /// BCP-47 language identifier (default: "en-US").
    var language: String
    
    nonisolated init(
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitchMultiplier: Float = 1.0,
        volume: Float = 1.0,
        language: String = "en-US"
    ) {
        self.rate = rate
        self.pitchMultiplier = pitchMultiplier
        self.volume = volume
        self.language = language
    }
    
    /// Standard natural tutor voice configuration.
    nonisolated static let `default` = VoiceOutputConfiguration()
}

// MARK: - Voice Output Service Protocol

/// Abstract interface for delivering spoken tutor guidance.
protocol VoiceOutputServiceProtocol: Sendable {
    /// Current speech synthesizer state.
    var state: SpeechState { get async }
    
    /// Speaks the given structured tutor response, respecting queue priorities and duplicate suppression.
    func speak(_ response: TutorResponse) async
    
    /// Convenience helper speaking raw text with default normal priority.
    func speak(_ text: String) async
    
    /// Immediately stops speech playback and clears the active utterance.
    func stop() async
    
    /// Pauses active speech playback.
    func pause() async
    
    /// Resumes paused speech playback.
    func resume() async
}

extension VoiceOutputServiceProtocol {
    func speak(_ text: String) async {
        await speak(TutorResponse(text: text, priority: .normal))
    }
}
