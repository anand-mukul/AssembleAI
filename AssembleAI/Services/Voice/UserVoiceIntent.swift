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
    
    /// Pause or stop the active session ("stop", "pause").
    case stopTask
    
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
        
        // 1. Repeat Instruction Patterns
        if tokenSet.contains("repeat") || tokenSet.contains("pardon") ||
           text == "say that again" || text == "say again" || text == "what did you say" ||
           text.contains("repeat that") {
            return .repeatInstruction
        }
        
        // 2. Ask Why Patterns
        if text.starts(with: "why") || tokenSet.contains("why") || text.contains("explain") {
            return .askWhy
        }
        
        // 3. Ask What Next Patterns
        if text.contains("next") || text.contains("what now") || (tokenSet.contains("what") && tokenSet.contains("do")) {
            return .askWhatNext
        }
        
        // 4. Ask Where Patterns
        if tokenSet.contains("where") || text.contains("where does") || text.contains("where do i put") {
            return .askWhere
        }
        
        // 5. Request Help / Stuck Patterns
        if tokenSet.contains("stuck") || tokenSet.contains("help") || text.contains("confused") {
            return .requestHelp
        }
        
        // 6. Request Visual Help Patterns
        if text.contains("show me") || tokenSet.contains("highlight") || text.contains("visual") || text.contains("point") {
            return .requestVisualHelp
        }
        
        // 7. Ask Polarity / Orientation Patterns
        if tokenSet.contains("polarity") || tokenSet.contains("anode") || tokenSet.contains("cathode") ||
           tokenSet.contains("positive") || tokenSet.contains("negative") || text.contains("which way") ||
           text.contains("which side") || text.contains("orientation") {
            return .askPolarity
        }
        
        // 8. Ask If Correct Patterns
        if text.contains("correct") || text.contains("is this right") || text.contains("check this") ||
           text.contains("did i do") || text.contains("how does this look") {
            return .askIsCorrect
        }
        
        // 9. Continue Task Patterns
        if tokenSet.contains("continue") || tokenSet.contains("proceed") || tokenSet.contains("done") ||
           text == "next step" || text == "let's go" {
            return .continueTask
        }
        
        // 10. Stop Task Patterns
        if tokenSet.contains("stop") || tokenSet.contains("pause") || tokenSet.contains("cancel") || tokenSet.contains("exit") {
            return .stopTask
        }
        
        // 11. Unknown Fallback
        return .unknown(transcript: rawTranscript)
    }
}
