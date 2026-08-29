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
    
    var configuration: VoiceOutputConfiguration
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentResponse: TutorResponse? = nil
    private var lastSpokenText: String? = nil
    private var lastSpokenTimestamp: Date? = nil
    
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
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Audio session setup failure handled gracefully
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
        if synthesizer.isSpeaking, let active = currentResponse {
            if response.priority >= active.priority {
                // Higher or equal priority: interrupt and preempt current speech immediately
                synthesizer.stopSpeaking(at: .immediate)
            } else {
                // Lower priority incoming speech while higher priority is speaking: drop lower priority
                return
            }
        }
        
        // 3. Prepare AVSpeechUtterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = configuration.rate
        utterance.pitchMultiplier = configuration.pitchMultiplier
        utterance.volume = configuration.volume
        
        if let voice = AVSpeechSynthesisVoice(language: configuration.language) {
            utterance.voice = voice
        }
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Graceful fallback
        }
        #endif
        
        currentResponse = response
        lastSpokenText = text
        lastSpokenTimestamp = Date()
        currentUtteranceText = text
        state = .speaking
        
        synthesizer.speak(utterance)
    }
    
    func stop() async {
        guard synthesizer.isSpeaking || state != .idle else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentResponse = nil
        currentUtteranceText = nil
        state = .idle
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
            self.state = .idle
            self.currentResponse = nil
            self.currentUtteranceText = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .idle
            self.currentResponse = nil
            self.currentUtteranceText = nil
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

// MARK: - Mock Voice Output Service

/// Actor-isolated mock voice output service recording spoken responses and state transitions for unit testing.
actor MockVoiceOutputService: VoiceOutputServiceProtocol {
    private var _state: SpeechState = .idle
    var state: SpeechState { _state }
    
    private(set) var spokenResponses: [TutorResponse] = []
    private(set) var stopCount: Int = 0
    private(set) var pauseCount: Int = 0
    private(set) var resumeCount: Int = 0
    
    init() {}
    
    func speak(_ response: TutorResponse) async {
        if let last = spokenResponses.last, last.text == response.text,
           Date().timeIntervalSince(last.timestamp) < 3.0 {
            return
        }
        
        if _state == .speaking, let active = spokenResponses.last {
            if response.priority < active.priority {
                return
            }
            stopCount += 1
        }
        
        spokenResponses.append(response)
        _state = .speaking
    }
    
    func stop() async {
        stopCount += 1
        _state = .idle
    }
    
    func pause() async {
        pauseCount += 1
        _state = .paused
    }
    
    func resume() async {
        resumeCount += 1
        _state = .speaking
    }
    
    func reset() {
        spokenResponses.removeAll()
        stopCount = 0
        pauseCount = 0
        resumeCount = 0
        _state = .idle
    }
}
