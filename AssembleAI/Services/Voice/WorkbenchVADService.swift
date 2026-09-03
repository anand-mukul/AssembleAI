//
//  WorkbenchVADService.swift
//  AssembleAI
//

import Foundation
import AVFoundation

/// Voice activity detection events emitted from real-time audio buffer analysis.
nonisolated enum VADEvent: Sendable, Equatable {
    /// Human speech onset detected.
    case speechStarted(timestamp: Date)
    /// Ongoing speech utterance.
    case speechOngoing(duration: Double, energyDb: Double)
    /// Speech has ceased (trailing silence window elapsed).
    case speechEnded(duration: Double)
    /// Background ambient silence / non-speech noise.
    case silence
}

/// Configuration thresholds for workbench voice activity detection.
nonisolated struct WorkbenchVADConfiguration: Sendable, Equatable {
    /// Speech energy threshold in dBFS (default: -38.0 dBFS).
    var speechThresholdDb: Double
    /// Minimum speech duration required to confirm genuine speech onset (default: 0.12s, filters clicks).
    var minimumSpeechDurationSeconds: Double
    /// Trailing silence duration required to trigger speech end (default: 0.45s).
    var trailingSilenceDurationSeconds: Double
    /// Zero-crossing rate threshold to filter high-frequency fan hiss (default: 0.35).
    var maxNoiseZeroCrossingRate: Double
    
    init(
        speechThresholdDb: Double = -38.0,
        minimumSpeechDurationSeconds: Double = 0.12,
        trailingSilenceDurationSeconds: Double = 0.45,
        maxNoiseZeroCrossingRate: Double = 0.35
    ) {
        self.speechThresholdDb = speechThresholdDb
        self.minimumSpeechDurationSeconds = minimumSpeechDurationSeconds
        self.trailingSilenceDurationSeconds = trailingSilenceDurationSeconds
        self.maxNoiseZeroCrossingRate = maxNoiseZeroCrossingRate
    }
    
    static let `default` = WorkbenchVADConfiguration()
}

/// Real-time Voice Activity Detection (VAD) service analyzing workbench audio streams.
///
/// Distinguishes human speech from ambient workshop noise (fan hum, tool clicks, soldering irons)
/// using short-time RMS energy and zero-crossing rate analysis.
final class WorkbenchVADService: @unchecked Sendable {
    
    private let lock = NSLock()
    private var configuration: WorkbenchVADConfiguration
    
    // State Tracking
    private var isSpeechActive: Bool = false
    private var speechStartTime: Double? = nil
    private var lastSpeechTime: Double? = nil
    private var estimatedNoiseFloorDb: Double = -55.0
    
    init(configuration: WorkbenchVADConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Analyzes an incoming PCM audio buffer and produces a VAD event.
    func process(buffer: AVAudioPCMBuffer, timestamp: Double = CFAbsoluteTimeGetCurrent()) -> VADEvent {
        lock.lock()
        defer { lock.unlock() }
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return .silence
        }
        
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return .silence }
        
        // 1. Calculate RMS Energy
        var sumSquares: Float = 0.0
        var zeroCrossings = 0
        var prevSample: Float = channelData[0]
        
        for i in 0..<frameCount {
            let sample = channelData[i]
            sumSquares += sample * sample
            
            // Zero-crossing check
            if (sample >= 0 && prevSample < 0) || (sample < 0 && prevSample >= 0) {
                zeroCrossings += 1
            }
            prevSample = sample
        }
        
        let rms = sqrt(sumSquares / Float(frameCount))
        let energyDb = Double(20.0 * log10(max(1e-5, rms)))
        let zcr = Double(zeroCrossings) / Double(frameCount)
        
        // Adaptive noise floor tracking during quiet periods
        if energyDb < -45.0 && !isSpeechActive {
            estimatedNoiseFloorDb = 0.95 * estimatedNoiseFloorDb + 0.05 * energyDb
        }
        
        // Effective speech threshold: configured threshold or 12dB above ambient noise floor
        let effectiveThreshold = max(configuration.speechThresholdDb, estimatedNoiseFloorDb + 12.0)
        let isFrameVoiced = (energyDb > effectiveThreshold) && (zcr < configuration.maxNoiseZeroCrossingRate)
        
        // 2. State Machine
        if isFrameVoiced {
            lastSpeechTime = timestamp
            
            if !isSpeechActive {
                if speechStartTime == nil {
                    speechStartTime = timestamp
                }
                
                let candidateDuration = timestamp - speechStartTime!
                if candidateDuration >= configuration.minimumSpeechDurationSeconds {
                    isSpeechActive = true
                    return .speechStarted(timestamp: Date())
                }
                return .silence
            } else {
                let duration = timestamp - (speechStartTime ?? timestamp)
                return .speechOngoing(duration: duration, energyDb: energyDb)
            }
        } else {
            // Unvoiced frame
            if isSpeechActive {
                let silenceDuration = timestamp - (lastSpeechTime ?? timestamp)
                if silenceDuration >= configuration.trailingSilenceDurationSeconds {
                    let totalDuration = (lastSpeechTime ?? timestamp) - (speechStartTime ?? timestamp)
                    isSpeechActive = false
                    speechStartTime = nil
                    lastSpeechTime = nil
                    return .speechEnded(duration: max(0.2, totalDuration))
                } else {
                    let duration = timestamp - (speechStartTime ?? timestamp)
                    return .speechOngoing(duration: duration, energyDb: energyDb)
                }
            } else {
                // If candidate speech never reached minimum duration, reset
                if let start = speechStartTime, (timestamp - start) > configuration.trailingSilenceDurationSeconds {
                    speechStartTime = nil
                }
                return .silence
            }
        }
    }
    
    /// Resets VAD state and noise floor tracking.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        isSpeechActive = false
        speechStartTime = nil
        lastSpeechTime = nil
        estimatedNoiseFloorDb = -55.0
    }
}
