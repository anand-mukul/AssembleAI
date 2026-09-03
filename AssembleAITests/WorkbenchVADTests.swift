//
//  WorkbenchVADTests.swift
//  AssembleAITests
//

import XCTest
import AVFoundation
@testable import AssembleAI

final class WorkbenchVADTests: XCTestCase {
    
    private var vad: WorkbenchVADService!
    
    override func setUp() {
        super.setUp()
        vad = WorkbenchVADService(
            configuration: WorkbenchVADConfiguration(
                speechThresholdDb: -35.0,
                minimumSpeechDurationSeconds: 0.05,
                trailingSilenceDurationSeconds: 0.15
            )
        )
    }
    
    override func tearDown() {
        vad = nil
        super.tearDown()
    }
    
    // MARK: - Helpers to Create Audio Buffers
    
    private func createSilenceBuffer(sampleCount: Int = 1024) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<sampleCount {
            channelData[i] = 0.0
        }
        return buffer
    }
    
    private func createSineWaveBuffer(amplitude: Float = 0.3, frequency: Float = 440.0, sampleCount: Int = 1024) -> AVAudioPCMBuffer {
        let sampleRate: Float = 16000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<sampleCount {
            let t = Float(i) / sampleRate
            channelData[i] = amplitude * sin(2.0 * .pi * frequency * t)
        }
        return buffer
    }
    
    // MARK: - Tests
    
    func testSilenceProducesSilenceEvent() {
        let silence = createSilenceBuffer()
        let event = vad.process(buffer: silence, timestamp: 0.0)
        XCTAssertEqual(event, .silence)
    }
    
    func testSpeechWaveformTriggersSpeechStarted() {
        let speech = createSineWaveBuffer(amplitude: 0.4, frequency: 300.0)
        
        // Frame 1: onset
        _ = vad.process(buffer: speech, timestamp: 0.0)
        
        // Frame 2: exceeds minimum duration 0.05s
        let event = vad.process(buffer: speech, timestamp: 0.08)
        
        switch event {
        case .speechStarted:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected .speechStarted event, got \(event)")
        }
    }
    
    func testSilenceAfterSpeechTriggersSpeechEnded() {
        let speech = createSineWaveBuffer(amplitude: 0.4, frequency: 300.0)
        let silence = createSilenceBuffer()
        
        // Start speech
        _ = vad.process(buffer: speech, timestamp: 0.0)
        _ = vad.process(buffer: speech, timestamp: 0.08) // speechStarted
        
        // Ongoing speech
        _ = vad.process(buffer: speech, timestamp: 0.20)
        
        // Silence begins
        _ = vad.process(buffer: silence, timestamp: 0.25)
        
        // Silence exceeds trailing duration (0.15s)
        let endEvent = vad.process(buffer: silence, timestamp: 0.45)
        
        switch endEvent {
        case .speechEnded(let duration):
            XCTAssertGreaterThan(duration, 0.0)
        default:
            XCTFail("Expected .speechEnded event, got \(endEvent)")
        }
    }
    
    func testResetClearsState() {
        let speech = createSineWaveBuffer(amplitude: 0.4, frequency: 300.0)
        _ = vad.process(buffer: speech, timestamp: 0.0)
        _ = vad.process(buffer: speech, timestamp: 0.08)
        
        vad.reset()
        
        let silence = createSilenceBuffer()
        let event = vad.process(buffer: silence, timestamp: 0.5)
        XCTAssertEqual(event, .silence)
    }
}
