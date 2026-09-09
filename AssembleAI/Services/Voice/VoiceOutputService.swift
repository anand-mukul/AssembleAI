//
//  VoiceOutputService.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Combine

/// Concrete voice output service orchestrating `AVSpeechSynthesizer` and `AVAudioSession`.
///
/// Implements priority-based speech interruption, duplicate speech suppression, and natural speech rate configuration.
@MainActor
final class VoiceOutputService: NSObject, ObservableObject, VoiceOutputServiceProtocol {
    @Published private(set) var state: SpeechState = .idle
    @Published private(set) var currentUtteranceText: String? = nil
    @Published private(set) var lastError: String? = nil
    
    var configuration: VoiceOutputConfiguration
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentResponse: TutorResponse? = nil
    private var lastSpokenText: String? = nil
    private var lastSpokenTimestamp: Date? = nil
    private var activeContinuation: CheckedContinuation<Void, Never>? = nil
    
    init(configuration: VoiceOutputConfiguration = .default) {
        self.configuration = configuration
        super.init()
        self.synthesizer.delegate = self
        configureAudioSession()
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AudioSessionCoordinator.shared.activateWorkbenchAudioSession()
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
        }
        #endif
    }
    
    // MARK: - VoiceOutputServiceProtocol
    
    func speak(_ response: TutorResponse) async {
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 1. Duplicate Speech Suppression
        if let lastText = lastSpokenText, lastText == text,
           let lastTime = lastSpokenTimestamp, Date().timeIntervalSince(lastTime) < 3.0 {
            return
        }
        
        // 2. Priority Preemption Check
        if synthesizer.isSpeaking || activeContinuation != nil, let active = currentResponse {
            if response.priority >= active.priority {
                // Higher or equal priority: interrupt and preempt current speech immediately
                synthesizer.stopSpeaking(at: .immediate)
                finishActiveUtterance()
            } else {
                // Lower priority incoming speech while higher priority is speaking: drop lower priority
                return
            }
        } else if activeContinuation != nil {
            finishActiveUtterance()
        }
        
        // 3. Prepare AVSpeechUtterance with natural cadence
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(configuration.rate, 0.49)
        utterance.pitchMultiplier = configuration.pitchMultiplier
        utterance.volume = configuration.volume
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.1
        
        if let naturalVoice = resolveNaturalVoice() {
            utterance.voice = naturalVoice
        }
        
        #if os(iOS)
        do {
            try AudioSessionCoordinator.shared.activateWorkbenchAudioSession()
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
        }
        #endif
        
        currentResponse = response
        lastSpokenText = text
        lastSpokenTimestamp = Date()
        currentUtteranceText = text
        state = .speaking
        
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.activeContinuation = continuation
                self.synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in
                self.synthesizer.stopSpeaking(at: .immediate)
                self.finishActiveUtterance()
            }
        }
    }
    
    // MARK: - Natural Voice Resolution
    
    /// Selects the highest available fidelity Apple natural/enhanced speech voice for conversational guidance.
    private func resolveNaturalVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        if let premium = allVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = allVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: configuration.language)
    }
    
    func stop() async {
        guard synthesizer.isSpeaking || state != .idle || activeContinuation != nil else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finishActiveUtterance()
    }
    
    func pause() async {
        guard synthesizer.isSpeaking, state == .speaking else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        state = .paused
    }
    
    func resume() async {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }
    
    private func finishActiveUtterance() {
        self.state = .idle
        self.currentResponse = nil
        self.currentUtteranceText = nil
        let cont = self.activeContinuation
        self.activeContinuation = nil
        cont?.resume()
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceOutputService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .speaking
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishActiveUtterance()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishActiveUtterance()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .paused
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .speaking
        }
    }
}

