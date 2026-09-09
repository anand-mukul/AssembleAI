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
    private var silenceWatchdogTask: Task<Void, Never>?
    
    nonisolated private let broadcaster = TranscriptStreamBroadcaster()
    
    override init() {
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    deinit {
        silenceWatchdogTask?.cancel()
        broadcaster.finishAll()
    }
    
    // MARK: - Transcript Stream API
    
    nonisolated var transcriptStream: AsyncStream<UserVoiceMessage> {
        let broadcaster = self.broadcaster
        return AsyncStream(UserVoiceMessage.self, bufferingPolicy: .bufferingNewest(10)) { continuation in
            let id = UUID()
            broadcaster.addContinuation(continuation, id: id)
            
            continuation.onTermination = { _ in
                broadcaster.removeContinuation(id: id)
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
        
        // 2. Configure Audio Session via Coordinator
        do {
            try AudioSessionCoordinator.shared.activateWorkbenchAudioSession()
        } catch {
            throw error
        }
        #endif
        
        // 3. Setup Recognition Request & Audio Engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            self.audioEngine = nil
            self.recognitionRequest = nil
            throw NSError(
                domain: "VoiceInputService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid audio input format: sample rate \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels"]
            )
        }
        
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
                        self.silenceWatchdogTask?.cancel()
                        self.silenceWatchdogTask = nil
                        await self.stopListening()
                    } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // 1.2s trailing silence watchdog for immediate real-time response
                        self.silenceWatchdogTask?.cancel()
                        self.silenceWatchdogTask = Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            guard !Task.isCancelled else { return }
                            guard let self = self, self.state == .listening else { return }
                            let finalText = self.latestTranscript
                            guard !finalText.isEmpty else { return }
                            self.broadcaster.broadcast(UserVoiceMessage(transcript: finalText, isFinal: true))
                            await self.stopListening()
                        }
                    }
                }
            }
            
            if error != nil {
                Task { @MainActor in
                    self.silenceWatchdogTask?.cancel()
                    self.silenceWatchdogTask = nil
                    await self.stopListening()
                }
            }
        }
    }
    
    func stopListening() async {
        guard state == .listening else { return }
        
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        state = .processing
        
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.finish()
        recognitionTask = nil
        
        state = .idle
    }
    
    func cancelListening() async {
        guard state == .listening || state == .processing else { return }
        
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
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

nonisolated final class TranscriptStreamBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<UserVoiceMessage>.Continuation] = [:]
    
    nonisolated init() {}
    
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


extension VoiceInputService {
    /// Returns a hands-free continuous streaming speech service backed by Voice Activity Detection (VAD).
    static func continuousStreaming() -> StreamingSpeechService {
        StreamingSpeechService()
    }
}
