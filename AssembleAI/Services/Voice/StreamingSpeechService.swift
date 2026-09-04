//
//  StreamingSpeechService.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Speech
import Combine

/// Outcome of streaming speech recognition containing the transcript and parsed intent.
nonisolated struct RecognizedSpeechUtterance: Sendable, Equatable {
    let transcript: String
    let intent: UserVoiceIntent
    let isFinal: Bool
    let timestamp: Date
}

/// Hands-free continuous speech recognition engine driven by Voice Activity Detection (VAD).
///
/// Automatically opens audio buffers when speech is detected and closes when silence returns,
/// without requiring the user to tap or hold any buttons on screen.
@MainActor
final class StreamingSpeechService: NSObject, ObservableObject, SFSpeechRecognizerDelegate, VoiceInputServiceProtocol {
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isSpeechDetected: Bool = false
    @Published private(set) var latestTranscript: String = ""
    @Published private(set) var latestIntent: UserVoiceIntent? = nil
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let vadService = WorkbenchVADService()
    private let intentParser = VoiceIntentParser()
    private var bargeInManager: VoiceBargeInManager?
    
    private var utteranceContinuation: AsyncStream<RecognizedSpeechUtterance>.Continuation?
    
    override init() {
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    deinit {
        utteranceContinuation?.finish()
    }
    
    // MARK: - VoiceInputServiceProtocol Conformance
    
    nonisolated var state: VoiceInputState {
        get async {
            await MainActor.run {
                self.isListening ? .listening : .idle
            }
        }
    }
    
    nonisolated var transcriptStream: AsyncStream<UserVoiceMessage> {
        AsyncStream(UserVoiceMessage.self) { continuation in
            let task = Task { [weak self] in
                guard let stream = self?.utteranceStream else {
                    continuation.finish()
                    return
                }
                for await utterance in stream {
                    continuation.yield(
                        UserVoiceMessage(
                            transcript: utterance.transcript,
                            isFinal: utterance.isFinal,
                            timestamp: utterance.timestamp
                        )
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    func startListening() async throws {
        try await startContinuousListening()
    }
    
    func stopListening() async {
        stopContinuousListening()
    }
    
    func cancelListening() async {
        stopContinuousListening()
    }
    
    /// Stream of finalized and partial speech utterances with parsed intents.
    nonisolated var utteranceStream: AsyncStream<RecognizedSpeechUtterance> {
        AsyncStream(RecognizedSpeechUtterance.self) { [weak self] continuation in
            Task { @MainActor [weak self] in
                self?.utteranceContinuation = continuation
            }
        }
    }
    
    /// Attaches the barge-in manager for sub-80ms tutor silencing.
    func attachBargeInManager(_ manager: VoiceBargeInManager) {
        self.bargeInManager = manager
    }
    
    // MARK: - Lifecycle Control
    
    /// Starts hands-free continuous listening.
    func startContinuousListening() async throws {
        guard !isListening else { return }
        
        // 1. Activate centralized workbench audio session
        try AudioSessionCoordinator.shared.activateWorkbenchAudioSession()
        
        // 2. Request permissions if needed
        #if os(iOS)
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw NSError(domain: "StreamingSpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        }
        #endif
        
        let authStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard authStatus == .authorized else {
            throw NSError(domain: "StreamingSpeechService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        
        // 3. Configure Audio Engine & Tap
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Process real-time Voice Activity Detection
            let event = self.vadService.process(buffer: buffer)
            
            Task { @MainActor in
                self.handleVADEvent(event, buffer: buffer)
            }
        }
        
        engine.prepare()
        try engine.start()
        
        self.isListening = true
    }
    
    /// Stops continuous listening and releases audio hardware.
    func stopContinuousListening() {
        guard isListening else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        finalizeActiveUtterance()
        vadService.reset()
        
        self.isListening = false
        self.isSpeechDetected = false
        
        AudioSessionCoordinator.shared.deactivateSession()
    }
    
    // MARK: - VAD Event Handling
    
    private func handleVADEvent(_ event: VADEvent, buffer: AVAudioPCMBuffer) {
        // Feed barge-in manager
        bargeInManager?.handleVADEvent(event)
        
        switch event {
        case .speechStarted:
            self.isSpeechDetected = true
            beginSpeechRecognitionTask()
            recognitionRequest?.append(buffer)
            
        case .speechOngoing:
            self.isSpeechDetected = true
            recognitionRequest?.append(buffer)
            
        case .speechEnded:
            self.isSpeechDetected = false
            finalizeActiveUtterance()
            
        case .silence:
            break
        }
    }
    
    // MARK: - Speech Recognition Sub-Task
    
    private func beginSpeechRecognitionTask() {
        guard recognitionRequest == nil else { return }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request
        
        self.recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                let intent = self.intentParser.parse(text)
                
                self.latestTranscript = text
                self.latestIntent = intent
                
                let utterance = RecognizedSpeechUtterance(
                    transcript: text,
                    intent: intent,
                    isFinal: isFinal,
                    timestamp: Date()
                )
                self.utteranceContinuation?.yield(utterance)
            }
            
            if error != nil || result?.isFinal == true {
                self.finalizeActiveUtterance()
            }
        }
    }
    
    private func finalizeActiveUtterance() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
