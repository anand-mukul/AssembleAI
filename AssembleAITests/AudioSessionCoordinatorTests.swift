//
//  AudioSessionCoordinatorTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

@MainActor
final class AudioSessionCoordinatorTests: XCTestCase {
    
    func testCoordinatorSharedInstance() {
        let coordinator = AudioSessionCoordinator.shared
        XCTAssertNotNil(coordinator)
    }
    
    func testCoordinatorActivationState() {
        let coordinator = AudioSessionCoordinator.shared
        // Activation should not throw an unhandled fatal error on test hosts
        do {
            try coordinator.activateWorkbenchAudioSession()
            XCTAssertTrue(coordinator.isSessionActive)
        } catch {
            // Simulator without audio hardware permission will record error gracefully
            XCTAssertNotNil(coordinator.lastErrorMessage)
        }
    }
    
    func testCoordinatorDeactivation() {
        let coordinator = AudioSessionCoordinator.shared
        coordinator.deactivateSession()
        XCTAssertFalse(coordinator.isSessionActive)
    }
}
