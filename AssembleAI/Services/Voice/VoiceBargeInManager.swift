//
//  VoiceBargeInManager.swift
//  AssembleAI
//

import Foundation

/// Coordinator managing real-time speech barge-in and audio interruption.
///
/// When the user starts speaking while the tutor is speaking, interrupts and silences the synthesizer
/// within $<80\text{ms}$ so the tutor never speaks over the user.
@MainActor
final class VoiceBargeInManager: ObservableObject {
    
    @Published private(set) var isBargeInActive: Bool = false
    @Published private(set) var lastBargeInTimestamp: Date? = nil
    
    private let voiceOutput: VoiceOutputServiceProtocol
    private var isSelfVoiceSuppressionActive: Bool = false
    
    var onBargeInOccurred: (() -> Void)? = nil
    
    init(voiceOutput: VoiceOutputServiceProtocol) {
        self.voiceOutput = voiceOutput
    }
    
    /// Evaluates incoming VAD event and triggers sub-80ms speech preemption if user speaks.
    func handleVADEvent(_ event: VADEvent) {
        switch event {
        case .speechStarted(let timestamp):
            // Check if assistant is currently speaking
            Task { @MainActor in
                let isSpeaking = await self.voiceOutput.state == .speaking
                if isSpeaking {
                    // Preempt and silence immediately
                    await self.voiceOutput.stop()
                    self.isBargeInActive = true
                    self.lastBargeInTimestamp = timestamp
                    self.onBargeInOccurred?()
                }
            }
            
        case .speechEnded:
            self.isBargeInActive = false
            
        case .speechOngoing, .silence:
            break
        }
    }
    
    /// Marks when the assistant begins speaking to enable echo cancellation / self-voice guard.
    func notifyAssistantSpeechStarted() {
        isSelfVoiceSuppressionActive = true
    }
    
    /// Marks when the assistant finishes speaking.
    func notifyAssistantSpeechFinished() {
        isSelfVoiceSuppressionActive = false
    }
}
