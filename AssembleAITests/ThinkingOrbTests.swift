//
//  ThinkingOrbTests.swift
//  AssembleAITests
//
//  Unit tests verifying the native Swift port of Libraries.dev Thinking Orbs.
//

import XCTest
import SwiftUI
@testable import AssembleAI

@MainActor
final class ThinkingOrbTests: XCTestCase {
    
    // MARK: - Test 1: All Nine Official States Exist
    func testAllNineOfficialStates() {
        let expectedStates: [ThinkingOrbState] = [
            .working,
            .searching,
            .solving,
            .listening,
            .connecting,
            .weaving,
            .composing,
            .breathing,
            .shaping
        ]
        
        XCTAssertEqual(ThinkingOrbState.allCases.count, 9, "ThinkingOrb must ship exactly nine hand-tuned animated states")
        for state in expectedStates {
            XCTAssertTrue(ThinkingOrbState.allCases.contains(state), "State \(state.rawValue) must be present in allCases")
        }
    }
    
    // MARK: - Test 2: String Literal Initialization
    func testStringLiteralInitialization() {
        let searching: ThinkingOrbState = "searching"
        XCTAssertEqual(searching, .searching)
        
        let solving: ThinkingOrbState = "solving"
        XCTAssertEqual(solving, .solving)
        
        let listening: ThinkingOrbState = "listening"
        XCTAssertEqual(listening, .listening)
        
        let working: ThinkingOrbState = "working"
        XCTAssertEqual(working, .working)
        
        let connecting: ThinkingOrbState = "connecting"
        XCTAssertEqual(connecting, .connecting)
        
        let weaving: ThinkingOrbState = "weaving"
        XCTAssertEqual(weaving, .weaving)
        
        let composing: ThinkingOrbState = "composing"
        XCTAssertEqual(composing, .composing)
        
        let breathing: ThinkingOrbState = "breathing"
        XCTAssertEqual(breathing, .breathing)
        
        let shaping: ThinkingOrbState = "shaping"
        XCTAssertEqual(shaping, .shaping)
    }
    
    // MARK: - Test 3: ThinkingOrb Component Initialization
    func testThinkingOrbComponentProps() {
        // Chat-avatar scale (64)
        let orb64 = ThinkingOrb(state: .searching, size: 64)
        XCTAssertEqual(orb64.state, .searching)
        XCTAssertEqual(orb64.size, 64)
        XCTAssertEqual(orb64.speed, 1.0)
        XCTAssertNil(orb64.dark)
        XCTAssertFalse(orb64.paused)
        
        // Inline-text scale (20)
        let orb20 = ThinkingOrb(state: "listening", size: 20, speed: 1.5, dark: true, paused: true)
        XCTAssertEqual(orb20.state, .listening)
        XCTAssertEqual(orb20.size, 20)
        XCTAssertEqual(orb20.speed, 1.5)
        XCTAssertEqual(orb20.dark, true)
        XCTAssertTrue(orb20.paused)
    }
    
    // MARK: - Test 4: Size Enum Presets
    func testThinkingOrbSizePresets() {
        XCTAssertEqual(ThinkingOrbSize.px64.points, 64.0)
        XCTAssertEqual(ThinkingOrbSize.px20.points, 20.0)
        XCTAssertEqual(ThinkingOrbSize.custom(52).points, 52.0)
        
        let orbWithEnum = ThinkingOrb(state: .working, size: .px64)
        XCTAssertEqual(orbWithEnum.size, 64.0)
    }
    
    // MARK: - Test 5: Backwards Compatibility with LiveTutorStatus
    func testLiveTutorStatusCompatibility() {
        let liveOrb = ThinkingOrbView(status: .live, diameter: 52)
        XCTAssertEqual(liveOrb.state, .breathing)
        XCTAssertEqual(liveOrb.size, 52)
        
        let listeningOrb = ThinkingOrbView(status: .listening, diameter: 16)
        XCTAssertEqual(listeningOrb.state, .listening)
        XCTAssertEqual(listeningOrb.size, 16)
        
        let speakingOrb = ThinkingOrbView(status: .speaking, diameter: 24)
        XCTAssertEqual(speakingOrb.state, .composing)
        
        let verifyingOrb = ThinkingOrbView(status: .verifying, diameter: 72)
        XCTAssertEqual(verifyingOrb.state, .solving)
        
        let pausedOrb = ThinkingOrbView(status: .paused, diameter: 24)
        XCTAssertTrue(pausedOrb.paused)
    }
}
