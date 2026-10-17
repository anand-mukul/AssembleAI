//
//  UserVoiceIntentTests.swift
//  AssembleAITests
//

import XCTest
@testable import AssembleAI

final class UserVoiceIntentTests: XCTestCase {
    
    private let parser = VoiceIntentParser()
    
    func testParseRepeatInstruction() {
        XCTAssertEqual(parser.parse("repeat that"), .repeatInstruction)
        XCTAssertEqual(parser.parse("say again"), .repeatInstruction)
        XCTAssertEqual(parser.parse("what did you say?"), .repeatInstruction)
    }
    
    func testParseAskWhy() {
        XCTAssertEqual(parser.parse("why"), .askWhy)
        XCTAssertEqual(parser.parse("why is that?"), .askWhy)
        XCTAssertEqual(parser.parse("why is this wrong"), .askWhy)
    }
    
    func testParseAskWhatNext() {
        XCTAssertEqual(parser.parse("what's next"), .askWhatNext)
        XCTAssertEqual(parser.parse("what do i do next?"), .askWhatNext)
        XCTAssertEqual(parser.parse("what now"), .askWhatNext)
    }
    
    func testParseAskWhere() {
        XCTAssertEqual(parser.parse("where does this go"), .askWhere)
        XCTAssertEqual(parser.parse("where do i put this?"), .askWhere)
    }
    
    func testParseRequestHelp() {
        XCTAssertEqual(parser.parse("help"), .requestHelp)
        XCTAssertEqual(parser.parse("i'm stuck"), .requestHelp)
        XCTAssertEqual(parser.parse("i need help"), .requestHelp)
    }
    
    func testParseRequestVisualHelp() {
        XCTAssertEqual(parser.parse("show me"), .requestVisualHelp)
        XCTAssertEqual(parser.parse("highlight it"), .requestVisualHelp)
    }
    
    func testParseAskPolarity() {
        XCTAssertEqual(parser.parse("which way does this face?"), .askPolarity)
        XCTAssertEqual(parser.parse("which side is positive"), .askPolarity)
        XCTAssertEqual(parser.parse("is this the anode?"), .askPolarity)
        XCTAssertEqual(parser.parse("check the polarity"), .askPolarity)
    }
    
    func testParseAskIsCorrect() {
        XCTAssertEqual(parser.parse("is this right?"), .askIsCorrect)
        XCTAssertEqual(parser.parse("is this correct"), .askIsCorrect)
        XCTAssertEqual(parser.parse("check this"), .askIsCorrect)
        XCTAssertEqual(parser.parse("how does this look?"), .askIsCorrect)
    }
    
    func testParseContinueAndStop() {
        XCTAssertEqual(parser.parse("continue"), .continueTask)
        XCTAssertEqual(parser.parse("next"), .continueTask)
        XCTAssertEqual(parser.parse("pause"), .stopTask)
        XCTAssertEqual(parser.parse("stop"), .stopTask)
    }
    
    func testParseVerifyPlacement() {
        XCTAssertEqual(parser.parse("look carefully i already connected this to this"), .verifyPlacement)
        XCTAssertEqual(parser.parse("already connected"), .verifyPlacement)
        XCTAssertEqual(parser.parse("check again"), .verifyPlacement)
        XCTAssertEqual(parser.parse("look at this"), .verifyPlacement)
    }
    
    // MARK: - Senior Engineer Electronics Intents Tests
    
    func testParseAskSubstitution() {
        let parsed1 = parser.parse("can i use 330 ohm instead")
        if case .askSubstitution(let part) = parsed1 {
            XCTAssertTrue(part.contains("330 ohm"))
        } else {
            XCTFail("Expected .askSubstitution, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("can i substitute this resistor?")
        if case .askSubstitution = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askSubstitution, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("swap with 10k resistor instead")
        if case .askSubstitution = parsed3 {
            // Success
        } else {
            XCTFail("Expected .askSubstitution, got \(parsed3)")
        }
    }
    
    func testParseAskSafety() {
        let parsed1 = parser.parse("is this safe?")
        if case .askSafety = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askSafety, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("will this burn out?")
        if case .askSafety = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askSafety, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("did i cause a short circuit?")
        if case .askSafety = parsed3 {
            // Success
        } else {
            XCTFail("Expected .askSafety, got \(parsed3)")
        }
    }
    
    func testParseAskSpecs() {
        let parsed1 = parser.parse("what are the color bands for 10k?")
        if case .askSpecs = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askSpecs, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("how many ohms is this resistor?")
        if case .askSpecs = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askSpecs, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("what is the pinout?")
        if case .askSpecs = parsed3 {
            // Success
        } else {
            XCTFail("Expected .askSpecs, got \(parsed3)")
        }
    }
    
    func testParseDiagnoseIssue() {
        let parsed1 = parser.parse("why isn't the led turning on?")
        if case .diagnoseIssue = parsed1 {
            // Success
        } else {
            XCTFail("Expected .diagnoseIssue, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("why is it not working?")
        if case .diagnoseIssue = parsed2 {
            // Success
        } else {
            XCTFail("Expected .diagnoseIssue, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("what did i do wrong?")
        if case .diagnoseIssue = parsed3 {
            // Success
        } else {
            XCTFail("Expected .diagnoseIssue, got \(parsed3)")
        }
    }
    
    func testParseExplainTheory() {
        let parsed1 = parser.parse("how does this work?")
        if case .explainTheory = parsed1 {
            // Success
        } else {
            XCTFail("Expected .explainTheory, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("why do we need a resistor here?")
        if case .explainTheory = parsed2 {
            // Success
        } else {
            XCTFail("Expected .explainTheory, got \(parsed2)")
        }
    }
    
    // MARK: - Universal Physical & Mechanical Assembly Tests
    
    func testParseAskToolRecommendation() {
        let parsed1 = parser.parse("what tool do i need for this screw?")
        if case .askToolRecommendation = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askToolRecommendation, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("which screwdriver should i use for cam locks?")
        if case .askToolRecommendation = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askToolRecommendation, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("what allen key bit size do i need?")
        if case .askToolRecommendation = parsed3 {
            // Success
        } else {
            XCTFail("Expected .askToolRecommendation, got \(parsed3)")
        }
    }
    
    func testParseAskJointAlignment() {
        let parsed1 = parser.parse("is this joint square?")
        if case .askJointAlignment = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askJointAlignment, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("are the panels flush?")
        if case .askJointAlignment = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askJointAlignment, got \(parsed2)")
        }
        
        let parsed3 = parser.parse("check joint alignment")
        if case .askJointAlignment = parsed3 {
            // Success
        } else {
            XCTFail("Expected .askJointAlignment, got \(parsed3)")
        }
    }
    
    func testParseAskFastenerCount() {
        let parsed1 = parser.parse("how many screws left?")
        if case .askFastenerCount = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askFastenerCount, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("missing screw from the box")
        if case .askFastenerCount = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askFastenerCount, got \(parsed2)")
        }
    }
    
    func testParseAskKinematics() {
        let parsed1 = parser.parse("how tight should the timing belt be?")
        if case .askKinematics = parsed1 {
            // Success
        } else {
            XCTFail("Expected .askKinematics, got \(parsed1)")
        }
        
        let parsed2 = parser.parse("check the gear mesh backlash")
        if case .askKinematics = parsed2 {
            // Success
        } else {
            XCTFail("Expected .askKinematics, got \(parsed2)")
        }
    }
}

