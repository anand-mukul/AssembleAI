//
//  UserVoiceIntent.swift
//  AssembleAI
//

import Foundation

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
    
    /// Parses a raw user transcript into a deterministic `UserVoiceIntent`.
    func parse(_ rawTranscript: String) -> UserVoiceIntent {
        let text = normalize(rawTranscript)
        guard !text.isEmpty else {
            return .unknown(transcript: rawTranscript)
        }
        
        // 1. Repeat Instruction Patterns
        if text == "repeat" || text == "repeat that" || text == "say that again" ||
           text == "say again" || text == "what did you say" || text == "pardon" ||
           text == "can you repeat that" || text.contains("repeat") {
            return .repeatInstruction
        }
        
        // 2. Ask Why Patterns
        if text == "why" || text == "why is that" || text == "why is this wrong" ||
           text == "why though" || text == "explain why" || text.starts(with: "why ") {
            return .askWhy
        }
        
        // 3. Ask What Next Patterns
        if text == "what next" || text == "what's next" || text == "what do i do next" ||
           text == "what do i do now" || text == "what now" || text == "what should i do" ||
           text.contains("what next") || text.contains("what do i do") {
            return .askWhatNext
        }
        
        // 4. Ask Where Patterns
        if text == "where" || text == "where does this go" || text == "where should this go" ||
           text == "where does it go" || text == "where do i put this" || text == "where is it" ||
           text.contains("where does") || text.contains("where do i put") {
            return .askWhere
        }
        
        // 5. Request Help / Stuck Patterns
        if text == "help" || text == "i'm stuck" || text == "im stuck" || text == "i am stuck" ||
           text == "i need help" || text == "help me" || text == "stuck" || text.contains("need help") {
            return .requestHelp
        }
        
        // 6. Request Visual Help Patterns
        if text == "show me" || text == "highlight" || text == "show where" ||
           text == "visual help" || text == "point it out" || text.contains("show me") {
            return .requestVisualHelp
        }
        
        // 7. Ask Polarity / Orientation Patterns
        if text.contains("which way") || text.contains("positive") || text.contains("negative") ||
           text.contains("anode") || text.contains("cathode") || text.contains("polarity") ||
           text.contains("which side") || text.contains("how do i turn") || text.contains("orientation") {
            return .askPolarity
        }
        
        // 8. Ask If Correct Patterns
        if text == "is this right" || text == "is this correct" || text == "did i do this right" ||
           text == "check this" || text == "check my work" || text == "how does this look" ||
           text.contains("is this right") || text.contains("is it right") || text.contains("did i get") {
            return .askIsCorrect
        }
        
        // 9. Continue Task Patterns
        if text == "continue" || text == "let's continue" || text == "next step" ||
           text == "proceed" || text == "i'm done" || text == "done" || text == "next" {
            return .continueTask
        }
        
        // 10. Stop Task Patterns
        if text == "stop" || text == "pause" || text == "cancel" || text == "exit" {
            return .stopTask
        }
        
        // 11. Unknown Fallback
        return .unknown(transcript: rawTranscript)
    }
}
