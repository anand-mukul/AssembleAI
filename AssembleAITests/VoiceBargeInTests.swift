//
//  VoiceBargeInTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class VoiceBargeInTests: XCTestCase {
    
    // Test Double for VoiceOutputServiceProtocol
    private final class MockVoiceOutput: VoiceOutputServiceProtocol, @unchecked Sendable {
        var state: SpeechState = .idle
        var currentUtteranceText: String? = nil
        var stopCalledCount: Int = 0
        
        func speak(_ response: TutorResponse) async {
            state = .speaking
            currentUtteranceText = response.text
        }
        
        func stop() async {
            state = .idle
            currentUtteranceText = nil
            stopCalledCount += 1
        }
    }
    
    func testBargeInSilencesAssistantWhenSpeaking() async {
        let mockOutput = MockVoiceOutput()
        await mockOutput.speak(TutorResponse(text: "Hello, place the resistor in row 10.", priority: .standard))
        
        let bargeInManager = VoiceBargeInManager(voiceOutput: mockOutput)
        
        var callbackFired = false
        bargeInManager.onBargeInOccurred = {
            callbackFired = true
        }
        
        // Trigger speech started event
        let now = Date()
        bargeInManager.handleVADEvent(.speechStarted(timestamp: now))
        
        // Allow MainActor task to execute
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertTrue(bargeInManager.isBargeInActive)
        XCTAssertEqual(bargeInManager.lastBargeInTimestamp, now)
        XCTAssertTrue(callbackFired)
        XCTAssertEqual(mockOutput.stopCalledCount, 1)
        XCTAssertEqual(mockOutput.state, .idle)
    }
    
    func testBargeInClearsOnSpeechEnded() async {
        let mockOutput = MockVoiceOutput()
        let bargeInManager = VoiceBargeInManager(voiceOutput: mockOutput)
        
        bargeInManager.handleVADEvent(.speechStarted(timestamp: Date()))
        bargeInManager.handleVADEvent(.speechEnded(duration: 1.2))
        
        XCTAssertFalse(bargeInManager.isBargeInActive)
    }
}
