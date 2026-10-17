//
//  UserVoiceIntent.swift
//  AssembleAI
//

import Foundation
import NaturalLanguage

// MARK: - User Voice Intent

/// Semantic intents parsed from user spoken commands and questions.
nonisolated enum UserVoiceIntent: Sendable, Equatable {
    /// Repeat the current instruction or last assistant response ("repeat that", "say again").
    case repeatInstruction
    
    /// Ask why a component is placed or configured this way ("why?", "why is that?").
    case askWhy
    
    /// Ask what the next action is ("what next?", "what do I do now?").
    case askWhatNext
    
    /// Ask where a physical component should be inserted ("where does this go?", "where should I put this?").
    case askWhere
    
    /// Express that the user is stuck and needs guidance ("I'm stuck", "help me").
    case requestHelp
    
    /// Request visual overlay highlight on the camera viewfinder ("show me", "highlight it").
    case requestVisualHelp
    
    /// Ask about orientation or polarity ("which way does this face", "which side is positive", "is this the anode").
    case askPolarity
    
    /// Ask if current placement is correct ("is this right", "did I do this right", "check this").
    case askIsCorrect
    
    /// Confirm and continue the assembly session ("continue", "let's go").
    case continueTask
    
    /// User asserts or requests verification of a placement or connection ("look carefully", "i already connected", "check this again").
    case verifyPlacement
    
    /// Pause or stop the active session ("stop", "pause").
    case stopTask
    
    // MARK: - Senior Engineer & Electronics Co-Pilot Intents
    
    /// Inquire about component substitutions, tolerances, or alternatives ("can I use 330 ohm instead?", "can I swap this resistor?").
    case askSubstitution(partQuery: String)
    
    /// Inquire about electrical specs, resistor color bands, or component pinouts ("what are the color bands for 10k?", "how many ohms?").
    case askSpecs(query: String)
    
    /// Inquire about electrical safety, voltage limits, or burn-out hazards ("is this safe?", "will it burn out?", "short circuit?").
    case askSafety(query: String)
    
    /// Ask for root-cause diagnosis of why circuit is not functioning ("why isn't the LED turning on?", "why is it not working?").
    case diagnoseIssue(query: String)
    
    /// Inquire about electronics theory or component role in the circuit ("how does this work?", "why do we need a resistor here?").
    case explainTheory(query: String)
    
    // MARK: - Universal Physical & Mechanical Assembly Intents
    
    /// Inquire about recommended tools, driver bits, or torque precautions ("what tool do I use?", "which screwdriver?", "hex key size?").
    case askToolRecommendation(query: String)
    
    /// Inquire about joint alignment, squareness, or flush mounting ("is this joint square?", "are panels flush?").
    case askJointAlignment(query: String)
    
    /// Inquire about fastener counts or missing physical elements ("how many screws?", "how many bolts left?").
    case askFastenerCount(query: String)
    
    /// Inquire about mechanical motion, belt tension, gear mesh, or bearing press fits ("how tight should the belt be?", "gear backlash?").
    case askKinematics(query: String)
    
    /// Unsupported or general freeform speech query.
    case unknown(transcript: String)
}

// MARK: - User Voice Message Model

/// Structured user voice utterance message containing transcript text and finality status.
nonisolated struct UserVoiceMessage: Sendable, Equatable, Identifiable {
    let id: UUID
    let transcript: String
    let isFinal: Bool
    let timestamp: Date
    
    nonisolated init(
        id: UUID = UUID(),
        transcript: String,
        isFinal: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.transcript = transcript
        self.isFinal = isFinal
        self.timestamp = timestamp
    }
}

// MARK: - Voice Intent Parser

/// Deterministic natural language intent parser mapping raw transcripts to structured `UserVoiceIntent`s.
nonisolated struct VoiceIntentParser: Sendable {
    nonisolated init() {}
    
    /// Normalizes transcript text by trimming whitespace, lowercasing, and stripping trailing punctuation.
    func normalize(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while let last = cleaned.last, [".", "?", "!", ","].contains(last) {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Parses a raw user transcript into a structured `UserVoiceIntent` using Apple NaturalLanguage.
    func parse(_ rawTranscript: String) -> UserVoiceIntent {
        let text = normalize(rawTranscript)
        guard !text.isEmpty else {
            return .unknown(transcript: rawTranscript)
        }
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
        let tokenSet = Set(tokens)
        
        // 1. Navigation & Control
        if tokenSet.contains("repeat") || tokenSet.contains("pardon") ||
           text == "say that again" || text == "say again" || text == "what did you say" ||
           text.contains("repeat that") {
            return .repeatInstruction
        }
        
        if tokenSet.contains("stop") || tokenSet.contains("pause") || tokenSet.contains("cancel") || tokenSet.contains("exit") {
            return .stopTask
        }
        
        if tokenSet.contains("continue") || tokenSet.contains("proceed") || tokenSet.contains("done") ||
           text == "next" || text == "next step" || text == "let's go" {
            return .continueTask
        }
        
        // 2. Hardware Engineering: Component Substitutions
        if tokenSet.contains("substitute") || tokenSet.contains("swap") ||
           text.contains("instead of") || text.contains("can i use") && text.contains("instead") ||
           text.contains("use another") || text.contains("alternative part") ||
           (tokenSet.contains("use") && (tokenSet.contains("resistor") || tokenSet.contains("capacitor") || tokenSet.contains("transistor")) && tokenSet.contains("instead")) {
            return .askSubstitution(partQuery: text)
        }
        
        // 3. Hardware Engineering: Electrical Safety & Hazards
        if tokenSet.contains("smoke") || tokenSet.contains("fire") ||
           text.contains("burn out") || text.contains("blow up") || text.contains("short circuit") ||
           text.contains("is it safe") || text.contains("is this safe") || text.contains("will this burn") ||
           text.contains("overheat") || text.contains("too much current") || text.contains("too much voltage") {
            return .askSafety(query: text)
        }
        
        // 4. Hardware Engineering: Specs, Resistor Color Bands, Pinouts
        if text.contains("color band") || text.contains("color bands") || text.contains("bands for") ||
           text.contains("how many ohms") || text.contains("what resistance") || text.contains("what value") ||
           text.contains("pinout") || text.contains("datasheet") || text.contains("voltage rating") ||
           (tokenSet.contains("bands") && (tokenSet.contains("resistor") || tokenSet.contains("ohm"))) {
            return .askSpecs(query: text)
        }
        
        // 5. Hardware Engineering: Root Cause Diagnostics & Failure Analysis
        if text.contains("not working") || text.contains("won't work") || text.contains("isn't working") ||
           text.contains("not turning on") || text.contains("why isn't") || text.contains("no power") ||
           text.contains("no light") || text.contains("troubleshoot") || text.contains("what did i do wrong") {
            return .diagnoseIssue(query: text)
        }
        
        // 6. Hardware Engineering: Theory of Operation
        if text.contains("how does this work") || text.contains("how does it work") ||
           text.contains("why do we need") || text.contains("purpose of") || text.contains("theory behind") {
            return .explainTheory(query: text)
        }
        
        // 7. Universal Physical Assembly: Tool & Driver Recommendations
        if text.contains("what tool") || text.contains("which tool") || text.contains("what screwdriver") ||
           text.contains("which screwdriver") || text.contains("allen key") || text.contains("hex key") ||
           text.contains("bit size") || text.contains("rubber mallet") || text.contains("wrench") ||
           text.contains("torx") || text.contains("driver bit") || text.contains("use a hammer") ||
           text.contains("tool do i need") || text.contains("tool should i use") {
            return .askToolRecommendation(query: text)
        }
        
        // 8. Universal Physical Assembly: Joint Alignment & Squareness
        if text.contains("joint square") || text.contains("is it square") || text.contains("are the panels flush") ||
           text.contains("is this flush") || text.contains("joint aligned") || text.contains("joint alignment") ||
           text.contains("check joint") || text.contains("is the corner 90") || text.contains("squareness") {
            return .askJointAlignment(query: text)
        }
        
        // 9. Universal Physical Assembly: Fastener Count Verification
        if text.contains("how many screw") || text.contains("how many bolt") || text.contains("how many dowel") ||
           text.contains("how many fastener") || text.contains("missing screw") || text.contains("missing bolt") ||
           text.contains("fastener count") || text.contains("screws left") || text.contains("bolts left") {
            return .askFastenerCount(query: text)
        }
        
        // 10. Universal Physical Assembly: Mechanical Kinematics & Belts
        if text.contains("belt tension") || text.contains("how tight") || text.contains("timing belt") ||
           text.contains("gear mesh") || text.contains("backlash") || text.contains("bearing play") ||
           text.contains("press the bearing") || text.contains("kinematics") {
            return .askKinematics(query: text)
        }
        
        // 11. General Assembly Questions
        if text.starts(with: "why") || tokenSet.contains("why") || text.contains("explain") {
            return .askWhy
        }
        
        if text.contains("what's next") || text.contains("what next") || text.contains("what now") || (tokenSet.contains("what") && tokenSet.contains("do")) {
            return .askWhatNext
        }
        
        if tokenSet.contains("where") || text.contains("where does") || text.contains("where do i put") {
            return .askWhere
        }
        
        if tokenSet.contains("stuck") || tokenSet.contains("help") || text.contains("confused") {
            return .requestHelp
        }
        
        if text.contains("show me") || tokenSet.contains("highlight") || text.contains("visual") || text.contains("point") {
            return .requestVisualHelp
        }
        
        if tokenSet.contains("polarity") || tokenSet.contains("anode") || tokenSet.contains("cathode") ||
           tokenSet.contains("positive") || tokenSet.contains("negative") || text.contains("which way") ||
           text.contains("which side") || text.contains("orientation") {
            return .askPolarity
        }
        
        if text.contains("look carefully") || text.contains("already connected") ||
           text.contains("already did") || text.contains("already inserted") ||
           text.contains("already put") || text.contains("check again") ||
           text.contains("look at this") || text.contains("look at my") ||
           text.contains("i connected") || text.contains("i have connected") ||
           text.contains("i plugged") || text.contains("see if it's connected") {
            return .verifyPlacement
        }
        
        if text.contains("correct") || text.contains("is this right") || text.contains("check this") ||
           text.contains("did i do") || text.contains("how does this look") {
            return .askIsCorrect
        }
        
        return .unknown(transcript: rawTranscript)
    }
}
