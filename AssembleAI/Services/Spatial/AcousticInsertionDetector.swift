//
//  AcousticInsertionDetector.swift
//  AssembleAI
//

import Foundation
import AVFoundation
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

/// Multimodal acoustic sensor detecting micro-mechanical insertion transients (breadboard spring clip engagement,
/// tactile switch clicks, and screw clicks) to corroborate visual state verification.
public actor AcousticInsertionDetector {
    
    // MARK: - Event Types
    
    /// Detected acoustic transient signature.
    public struct AcousticEvent: Sendable, Equatable {
        public enum EventType: String, Sendable, Equatable {
            case breadboardSpringSnap
            case tactileSwitchClick
            case componentContact
            case generalTransientClick
        }
        
        public let type: EventType
        public let timestamp: CFAbsoluteTime
        public let confidence: Double
        public let peakDecibels: Float
        
        public init(
            type: EventType,
            timestamp: CFAbsoluteTime = CFAbsoluteTimeGetCurrent(),
            confidence: Double,
            peakDecibels: Float
        ) {
            self.type = type
            self.timestamp = timestamp
            self.confidence = confidence
            self.peakDecibels = peakDecibels
        }
    }
    
    // MARK: - Properties
    
    private var recentEvents: [AcousticEvent] = []
    private var isMonitoring: Bool = false
    private let minimumTransientDecibels: Float
    private let peakToAverageThreshold: Float
    private let maxStoredEvents: Int = 20
    
    // MARK: - Initialization
    
    public init(
        minimumTransientDecibels: Float = -24.0,
        peakToAverageThreshold: Float = 2.5
    ) {
        self.minimumTransientDecibels = minimumTransientDecibels
        self.peakToAverageThreshold = peakToAverageThreshold
    }
    
    // MARK: - Monitoring Lifecycle
    
    public func startMonitoring() {
        isMonitoring = true
        recentEvents.removeAll()
    }
    
    public func stopMonitoring() {
        isMonitoring = false
    }
    
    public func isCurrentlyMonitoring() -> Bool {
        return isMonitoring
    }
    
    // MARK: - Audio Buffer Processing
    
    /// Analyzes an incoming PCM audio buffer for mechanical insertion transients.
    ///
    /// Evaluates short-time energy (RMS), peak amplitude, and crest factor (peak-to-RMS ratio).
    /// Mechanical clicks/snaps exhibit high crest factor (>2.5) and fast onset (<15ms).
    public func processAudioBuffer(
        peakAmplitude: Float,
        rmsAmplitude: Float,
        sampleRate: Double = 44100.0
    ) -> AcousticEvent? {
        guard isMonitoring else { return nil }
        
        // Convert to dBFS
        let peakDB = 20.0 * log10(max(peakAmplitude, 1e-5))
        guard peakDB >= minimumTransientDecibels else { return nil }
        
        // Calculate crest factor (Peak / RMS)
        let crestFactor = rmsAmplitude > 0 ? (peakAmplitude / rmsAmplitude) : 0
        guard crestFactor >= peakToAverageThreshold else { return nil }
        
        // Classify transient signature
        let eventType: AcousticEvent.EventType
        let confidence: Double
        
        if crestFactor > 4.0 && peakDB > -15.0 {
            eventType = .breadboardSpringSnap
            confidence = min(0.95, Double(crestFactor) / 6.0)
        } else if crestFactor > 3.0 {
            eventType = .tactileSwitchClick
            confidence = min(0.85, Double(crestFactor) / 5.0)
        } else {
            eventType = .generalTransientClick
            confidence = 0.70
        }
        
        let event = AcousticEvent(
            type: eventType,
            timestamp: CFAbsoluteTimeGetCurrent(),
            confidence: confidence,
            peakDecibels: peakDB
        )
        
        recordEvent(event)
        return event
    }
    
    /// Records a manually injected or test event.
    public func recordEvent(_ event: AcousticEvent) {
        recentEvents.append(event)
        if recentEvents.count > maxStoredEvents {
            recentEvents.removeFirst(recentEvents.count - maxStoredEvents)
        }
    }
    
    // MARK: - Query & Sensor Fusion
    
    /// Checks if a mechanical insertion snap occurred within a given temporal window before or after a timestamp.
    ///
    /// Ideal for pairing with `HandPoseActivityDetector`:
    /// When hand withdrawal occurs, checking if an acoustic snap occurred within [-0.5s, +0.2s] verifies physical insertion.
    public func hasInsertionEventNear(timestamp: CFAbsoluteTime, toleranceSeconds: Double = 0.6) -> (detected: Bool, event: AcousticEvent?) {
        let matching = recentEvents.last { event in
            abs(event.timestamp - timestamp) <= toleranceSeconds
        }
        return (matching != nil, matching)
    }
    
    /// Returns all events detected within the last N seconds.
    public func eventsInLast(seconds: Double) -> [AcousticEvent] {
        let cutoff = CFAbsoluteTimeGetCurrent() - seconds
        return recentEvents.filter { $0.timestamp >= cutoff }
    }
    
    /// Clears recorded acoustic event history.
    public func clearHistory() {
        recentEvents.removeAll()
    }
}
