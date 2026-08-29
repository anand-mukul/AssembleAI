//
//  VoiceInputService.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Speech
import Combine

/// Concrete on-device speech recognition service using Apple's `Speech` framework and `AVAudioEngine`.
///
/// Converts microphone audio streams into real-time partial and final user transcripts.
@MainActor
final class VoiceInputService: NSObject, ObservableObject, VoiceInputServiceProtocol {
    @Published private(set) var state: VoiceInputState = .idle
    @Published private(set) var latestTranscript: String = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    nonisolated private let broadcaster = TranscriptStreamBroadcaster()
    
    override init() {
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    deinit {
        broadcaster.finishAll()
    }
    
    // MARK: - Transcript Stream API
    
    nonisolated var transcriptStream: AsyncStream<UserVoiceMessage> {
        AsyncStream(UserVoiceMessage.self, bufferingPolicy: .bufferingNewest(10)) { continuation in
            let id = UUID()
            self.broadcaster.addContinuation(continuation, id: id)
            
            continuation.onTermination = { [weak self] _ in
                self?.broadcaster.removeContinuation(id: id)
            }
        }
    }
    
    // MARK: - VoiceInputServiceProtocol
    
    func startListening() async throws {
        guard state == .idle else { return }
        
        // 1. Check & Request Permissions
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            throw NSError(domain: "VoiceInputService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        #if os(iOS)
        let audioGranted = await AVAudioApplication.requestRecordPermission()
        guard audioGranted else {
            throw NSError(domain: "VoiceInputService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        }
        
        // 2. Configure Audio Session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw error
        }
        #endif
        
        // 3. Setup Recognition Request & Audio Engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        engine.prepare()
        try engine.start()
        
        self.state = .listening
        self.latestTranscript = ""
        
        // 4. Start Recognition Task
        self.recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                Task { @MainActor in
                    self.latestTranscript = text
                    self.broadcaster.broadcast(UserVoiceMessage(transcript: text, isFinal: isFinal))
                    
                    if isFinal {
                        await self.stopListening()
                    }
                }
            }
            
            if error != nil {
                Task { @MainActor in
                    await self.stopListening()
                }
            }
        }
    }
    
    func stopListening() async {
        guard state != .idle else { return }
        
        state = .processing
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.finish()
        recognitionTask = nil
        
        state = .idle
    }
    
    func cancelListening() async {
        guard state != .idle else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        state = .idle
        latestTranscript = ""
    }
    
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceInputService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            Task { @MainActor in
                await self.stopListening()
            }
        }
    }
}

// MARK: - Thread-Safe Transcript Stream Broadcaster

private final class TranscriptStreamBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<UserVoiceMessage>.Continuation] = [:]
    
    func addContinuation(_ continuation: AsyncStream<UserVoiceMessage>.Continuation, id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        continuations[id] = continuation
    }
    
    func removeContinuation(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        continuations.removeValue(forKey: id)
    }
    
    func broadcast(_ message: UserVoiceMessage) {
        lock.lock()
        let active = Array(continuations.values)
        lock.unlock()
        
        for cont in active {
            cont.yield(message)
        }
    }
    
    func finishAll() {
        lock.lock()
        let active = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()
        
        for cont in active {
            cont.finish()
        }
    }
}

// MARK: - Mock Voice Input Service

/// Thread-safe mock speech recognition service for unit testing and deterministic simulation.
final class MockVoiceInputService: VoiceInputServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    
    private var _state: VoiceInputState = .idle
    var state: VoiceInputState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }
    
    private var continuations: [UUID: AsyncStream<UserVoiceMessage>.Continuation] = [:]
    
    init() {}
    
    var transcriptStream: AsyncStream<UserVoiceMessage> {
        AsyncStream(UserVoiceMessage.self, bufferingPolicy: .bufferingNewest(10)) { continuation in
            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            self.lock.unlock()
            
            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
    
    func startListening() async throws {
        lock.lock()
        defer { lock.unlock() }
        _state = .listening
    }
    
    func stopListening() async {
        lock.lock()
        defer { lock.unlock() }
        _state = .idle
    }
    
    func cancelListening() async {
        lock.lock()
        defer { lock.unlock() }
        _state = .idle
    }
    
    /// Injects a simulated spoken transcript for unit testing.
    func simulateSpokenTranscript(_ text: String, isFinal: Bool) {
        let message = UserVoiceMessage(transcript: text, isFinal: isFinal)
        
        lock.lock()
        let activeContinuations = Array(continuations.values)
        if isFinal {
            _state = .idle
        }
        lock.unlock()
        
        for continuation in activeContinuations {
            continuation.yield(message)
        }
    }
}
