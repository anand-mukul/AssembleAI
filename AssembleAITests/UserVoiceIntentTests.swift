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
}
