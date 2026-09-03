//
//  HandPoseActivityDetectorTests.swift
//  AssembleAITests
//

import XCTest
import CoreGraphics
@testable import AssembleAI

final class HandPoseActivityDetectorTests: XCTestCase {
    
    func testWorkbenchHandActivityStates() {
        XCTAssertEqual(WorkbenchHandActivity.handsWorking.rawValue, "handsWorking")
        XCTAssertEqual(WorkbenchHandActivity.handsRetreated.rawValue, "handsRetreated")
        XCTAssertEqual(WorkbenchHandActivity.clear.rawValue, "clear")
    }
    
    func testHandActivityObservationProperties() {
        let obs = HandActivityObservation(
            activity: .handsWorking,
            detectedHandsCount: 2,
            handBoundingBoxes: [CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2)],
            isTargetOccluded: true,
            timestamp: Date()
        )
        
        XCTAssertEqual(obs.activity, .handsWorking)
        XCTAssertEqual(obs.detectedHandsCount, 2)
        XCTAssertTrue(obs.isTargetOccluded)
        XCTAssertEqual(obs.handBoundingBoxes.count, 1)
    }
}
