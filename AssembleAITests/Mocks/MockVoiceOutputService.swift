//
//  MockVoiceOutputService.swift
//  AssembleAITests
//

import Foundation
@testable import AssembleAI

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
