//
//  TutorResponse.swift
//  AssembleAI
//

import Foundation
import NaturalLanguage

// MARK: - Token Estimator

/// Empirical on-device token estimation for Apple Intelligence, Foundation Models, and conversational guidance.
/// Leverages Apple's `NaturalLanguage` word tokenizer combined with standard subword scaling (~1.3x words).
nonisolated enum TokenEstimator: Sendable {
    /// Estimates token count for arbitrary text prompt or model response.
    nonisolated static func estimate(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = trimmed
        var wordCount = 0
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { _, _ in
            wordCount += 1
            return true
        }
        if wordCount > 0 {
            // Standard NLP empirical ratio: ~1.3 tokens per English word (incorporating punctuation and subwords)
            return max(1, Int(ceil(Double(wordCount) * 1.3)))
        }
        // Fallback for non-whitespace/symbol strings: ~4 characters per token
        return max(1, Int(ceil(Double(trimmed.count) / 4.0)))
    }
}

// MARK: - Response Priority

/// Priority level governing speech queue interruption and replacement.
nonisolated enum ResponsePriority: Int, Sendable, Comparable, Codable {
    /// Optional or background encouragement.
    case low = 1
    /// Standard step orientation or confirmation.
    case normal = 2
    /// Proactive corrective guidance.
    case high = 3
    /// Direct user-requested answers or critical safety prompts.
    case immediate = 4
    
    nonisolated static func < (lhs: ResponsePriority, rhs: ResponsePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Tutor Response Model

/// Spoken tutor utterance with metadata for speech synthesis and telemetry.
///
/// `text` is the clean spoken-track string fed to `AVSpeechSynthesizer` (emoji-free).
/// `displayText` is the rich visual-track string shown in the HUD (may contain emojis).
nonisolated struct TutorResponse: Sendable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let displayText: String?
    let priority: ResponsePriority
    let category: String
    let timestamp: Date
    let inputTokens: Int?
    let outputTokens: Int?
    
    /// Rich text for on-screen HUD display. Falls back to `text` if `displayText` is nil.
    var textForDisplay: String { displayText ?? text }
    
    nonisolated init(
        id: UUID = UUID(),
        text: String,
        displayText: String? = nil,
        priority: ResponsePriority = .normal,
        category: String = "general",
        timestamp: Date = Date(),
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.displayText = displayText
        self.priority = priority
        self.category = category
        self.timestamp = timestamp
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens ?? (text.isEmpty ? nil : TokenEstimator.estimate(text))
    }
}

// MARK: - Emoji Utilities

extension TutorResponse {
    /// Creates a TutorResponse from raw LLM output, automatically splitting display and spoken tracks.
    /// Emojis are preserved in `displayText` for HUD rendering but stripped from `text` for speech synthesis.
    nonisolated static func fromModelOutput(
        _ rawText: String,
        priority: ResponsePriority = .normal,
        category: String = "general",
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) -> TutorResponse {
        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenText = Self.stripEmojis(cleaned)
        let outTokens = outputTokens ?? TokenEstimator.estimate(cleaned)
        return TutorResponse(
            text: spokenText,
            displayText: cleaned,
            priority: priority,
            category: category,
            inputTokens: inputTokens,
            outputTokens: outTokens
        )
    }
    
    /// Strips emoji characters from text so AVSpeechSynthesizer doesn't read emoji names aloud.
    nonisolated static func stripEmojis(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            // Keep everything that is NOT an emoji presentation or symbol
            !scalar.properties.isEmojiPresentation &&
            !(scalar.properties.isEmoji && scalar.value > 0x23F && !scalar.properties.isASCIIHexDigit)
        }.map(String.init).joined()
         .replacingOccurrences(of: "  ", with: " ")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Tutor Response Providing Protocol

/// Protocol for translating behavioral intervention decisions into spoken natural language responses.
nonisolated protocol TutorResponseProviding: Sendable {
    /// Generates a spoken tutor response for an intervention decision.
    nonisolated func response(for decision: InterventionDecision) -> TutorResponse?
}

// MARK: - Deterministic Tutor Response Provider

/// Concrete deterministic response provider generating warm, witty, expert guide dialogue.
///
/// Features varied candidate pools, situational workshop humor, emoji-rich HUD display text,
/// clean AVSpeechSynthesizer voice tracks, and anti-repetition memory tracking.
nonisolated struct DeterministicTutorResponseProvider: TutorResponseProviding {
    private static let phraseLock = NSLock()
    private static var recentUtterances: [String] = []
    
    nonisolated init() {}
    
    private static func selectCandidate(from pool: [String], fallbackIndex: Int) -> String {
        phraseLock.lock()
        defer { phraseLock.unlock() }
        
        let freshCandidates = pool.filter { !recentUtterances.contains($0) }
        let picked = freshCandidates.randomElement() ?? pool[abs(fallbackIndex) % pool.count]
        
        recentUtterances.append(picked)
        if recentUtterances.count > 6 {
            recentUtterances.removeFirst()
        }
        return picked
    }
    
    nonisolated func response(for decision: InterventionDecision) -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        switch decision.action {
        case .remainSilent:
            return nil
            
        case .instruct(let step):
            let intros = [
                "Alright, apprentice! Time for Step \(step.stepOrder): \(step.title). Let's see those maker skills in action. 🛠️ \(step.instruction)",
                "Next up on the bench—Step \(step.stepOrder): \(step.title). Keep your goggles figurative or literal, and let's roll! 🚀 \(step.instruction)",
                "Step \(step.stepOrder): \(step.title). This is where the magic happens—or at least where things start looking like the manual! ✨ \(step.instruction)",
                "Here comes Step \(step.stepOrder): \(step.title). Pro tip: no hammer required yet! ⚡ \(step.instruction)",
                "Time for Step \(step.stepOrder): \(step.title). Deep breath, steady hands, you've got this! 💪 \(step.instruction)",
                "Behold, Step \(step.stepOrder): \(step.title). Let's get this lined up like a seasoned pro: 🎯 \(step.instruction)"
            ]
            let chosen = Self.selectCandidate(from: intros, fallbackIndex: step.stepOrder)
            let inTokens = TokenEstimator.estimate("\(step.title) \(step.instruction)")
            return TutorResponse.fromModelOutput(chosen, priority: .normal, category: "instruction", inputTokens: inTokens)
            
        case .confirm(let step):
            let confirmations = [
                "Boom! Nailed it—well, seated it perfectly! Step \(step.stepOrder) is locked in. 🎉",
                "Look at that fit! Awesome craftsmanship. Step \(step.stepOrder) is verified! 🛠️",
                "Spot on, craft master! That connection is rock solid. Let's keep this streak going! 💪",
                "High five, great job! Clean alignment, zero smoke, total perfection. Step \(step.stepOrder) done! ✨",
                "Perfect fit! You slotted that in like you've been doing this for decades. Step \(step.stepOrder) complete! 🚀",
                "Nicely done! Locked and loaded, that joint isn't going anywhere. Beautiful job on Step \(step.stepOrder)! 🔥",
                "Boom, verified! You're making this look way too easy. Onto the next! ⚡"
            ]
            let chosen = Self.selectCandidate(from: confirmations, fallbackIndex: step.stepOrder)
            let inTokens = TokenEstimator.estimate(step.title)
            return TutorResponse.fromModelOutput(chosen, priority: .normal, category: "confirmation", inputTokens: inTokens)
            
        case .correct(let description, let level):
            let pool: [String]
            let priority: ResponsePriority
            switch level {
            case .gentle:
                priority = .normal
                pool = [
                    "So close! Quick eagle-eye check: \(description) 🔍",
                    "Almost a bullseye! Just a tiny nudge needed: \(description) 🎯",
                    "Hold the phone! Your piece went exploring a bit: \(description) 👀",
                    "One millimeter away from greatness! Check this alignment: \(description) 📐"
                ]
            case .explicit:
                priority = .high
                pool = [
                    "Hold up, friend! That part took a slight scenic detour: \(description) 🧭",
                    "Easy there, speed racer! Let's dial this in before moving on: \(description) 🔧",
                    "A slight case of misplaced pins—let's reroute: \(description) ⚡",
                    "Whoa there, builder! Before you press down, double check: \(description) 🛑"
                ]
            case .detailed:
                priority = .high
                pool = [
                    "Don't sweat it—every master builder has pulled a part out and tried again. Here's the play: \(description) 💡",
                    "Measure twice, plug once! Let's get this joint straightened out: \(description) 🛠️",
                    "No worries at all, that's why I'm here! Let's walk through this together: \(description) 🤝",
                    "Step back and breathe! Even seasoned makers hit a snag. Let's adjust this: \(description) ☕"
                ]
            }
            let chosen = Self.selectCandidate(from: pool, fallbackIndex: description.count)
            let inTokens = TokenEstimator.estimate(description)
            return TutorResponse.fromModelOutput(chosen, priority: priority, category: "correction", inputTokens: inTokens)
            
        case .requestBetterView(let explanation):
            let viewPrompts = [
                "Give me a slightly better angle, partner! Tilt the camera a hair or bring it closer so I can admire your handiwork. 📸 \(explanation)",
                "I'm squinting here! Slide the workpiece a little more into the light or tilt down so I can verify those pins. 💡 \(explanation)",
                "A little more camera love over here—pull your hands back for one quick second so I get an unblocked view. 🔍 \(explanation)",
                "Hold steady and give me an eagle-eye view! Let's get that workpiece center frame. 🎯 \(explanation)"
            ]
            let chosen = Self.selectCandidate(from: viewPrompts, fallbackIndex: explanation.count)
            let inTokens = TokenEstimator.estimate(explanation)
            return TutorResponse.fromModelOutput(chosen, priority: .normal, category: "camera_guidance", inputTokens: inTokens)
            
        case .offerHelp(let step, _):
            let helpPrompts = [
                "Taking a breather on \(step.title)? Smart move—Rome wasn't assembled in a day, and neither is this masterpiece. Need a hint? ☕",
                "Puzzling over this one? Don't let the blueprints win! Check the green highlighted target on your screen, or ask me anything. 🧠",
                "Hey, step \(step.stepOrder) can be tricky. Take your time, make sure parts are oriented right, and I'll keep an eye out. 🛠️"
            ]
            let chosen = Self.selectCandidate(from: helpPrompts, fallbackIndex: step.stepOrder)
            let inTokens = TokenEstimator.estimate(step.title)
            return TutorResponse.fromModelOutput(chosen, priority: .normal, category: "stuck_help", inputTokens: inTokens)
            
        case .respondToUser(let query):
            let inTokens = TokenEstimator.estimate(query)
            let lower = query.lowercased()
            
            // 1. Resistor Color Band Queries
            if (lower.contains("band") || lower.contains("color") || lower.contains("resistor") || lower.contains("ohm")) &&
               !lower.contains("instead") && !lower.contains("substitute") {
                if let ohms = ResistorColorBandDecoder.parseNominalOhms(from: query) {
                    let bands = ResistorColorBandDecoder.bands(forOhms: ohms)
                    let bandsFormatted = bands.map { $0.capitalized }.joined(separator: ", ")
                    let decoded = ResistorColorBandDecoder.decode(bands: bands)
                    let formattedVal = decoded?.formattedValue ?? "\(Int(ohms))Ω"
                    return TutorResponse.fromModelOutput(
                        "For a \(formattedVal) resistor, the standard 4-band EIA color code is: \(bandsFormatted)! 🎨",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                }
            }
            
            // 2. Component Substitution Queries
            if lower.contains("instead") || lower.contains("substitute") || lower.contains("swap") || lower.contains("replace") {
                if let reqOhms = ResistorColorBandDecoder.parseNominalOhms(from: query) {
                    if reqOhms >= 180 && reqOhms <= 470 {
                        let current = (5.0 - 2.0) / reqOhms * 1000.0
                        return TutorResponse.fromModelOutput(
                            "Yes! A \(Int(reqOhms))Ω resistor is a safe substitute—forward current stays at a nominal \(String(format: "%.1f", current))mA with only a minor shift in LED brightness! 💡",
                            priority: .immediate,
                            category: "user_query_response",
                            inputTokens: inTokens
                        )
                    } else if reqOhms < 100 {
                        return TutorResponse.fromModelOutput(
                            "Caution: \(Int(reqOhms))Ω is too low! Forward current will exceed the 20–30mA safety threshold for standard LEDs and risk burning out the diode. ⚠️",
                            priority: .immediate,
                            category: "user_query_response",
                            inputTokens: inTokens
                        )
                    } else {
                        return TutorResponse.fromModelOutput(
                            "A \(Int(reqOhms))Ω resistor will work safely, though current will be significantly restricted and your component may appear dim. ⚡",
                            priority: .immediate,
                            category: "user_query_response",
                            inputTokens: inTokens
                        )
                    }
                }
                return TutorResponse.fromModelOutput(
                    "When substituting components, always ensure equal or higher voltage ratings and verify pinouts before applying power! 🛠️",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 3. Electrical Safety & Burn-Out Queries
            if lower.contains("safe") || lower.contains("burn") || lower.contains("smoke") || lower.contains("fire") || lower.contains("short") {
                return TutorResponse.fromModelOutput(
                    "Safety check: Ensure your current-limiting resistor is placed in series with the LED, and double-check that positive (+) and ground (-) rails are never bridged directly! ⚡",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 4. Component Polarity Queries
            if lower.contains("polarity") || lower.contains("anode") || lower.contains("cathode") || lower.contains("which way") || lower.contains("which side") {
                return TutorResponse.fromModelOutput(
                    "For LEDs and diodes: the longer lead is the Anode (+) connecting toward positive voltage; the shorter lead and flat lens notch is the Cathode (-) connecting toward ground. 🔌",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 5. Troubleshooting & Root-Cause Failure Queries
            if lower.contains("not working") || lower.contains("won't work") || lower.contains("isn't working") || lower.contains("not turning on") || lower.contains("no light") {
                return TutorResponse.fromModelOutput(
                    "Let's troubleshoot: 1) Verify that connected component pins share the exact same numbered tie-strip row. 2) Check LED polarity (long lead to positive). 3) Ensure jumper wires are fully seated. 🔍",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 6. Universal Physical Assembly: Tool & Driver Recommendations
            if lower.contains("what tool") || lower.contains("which tool") || lower.contains("screwdriver") ||
               lower.contains("allen") || lower.contains("hex key") || lower.contains("bit size") ||
               lower.contains("mallet") || lower.contains("wrench") || lower.contains("torx") {
                if lower.contains("cam") {
                    return TutorResponse.fromModelOutput(
                        "For cam lock fasteners: Use a Pozidriv PZ2 or 6mm flat-head screwdriver. Do NOT use an impact drill—turn clockwise ~180° until firm resistance is felt! 🪛",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                } else if lower.contains("hex") || lower.contains("allen") || lower.contains("bolt") || lower.contains("m4") || lower.contains("m5") || lower.contains("m3") {
                    return TutorResponse.fromModelOutput(
                        "For socket head bolts: Use the matching Hex / Allen key (typically 3mm or 4mm). Seat the key completely in the recess and hand-tighten until snug, plus a quarter turn! 🔧",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                } else if lower.contains("dowel") || lower.contains("wood") {
                    return TutorResponse.fromModelOutput(
                        "For wooden dowels: Press firmly by hand or tap gently with a rubber mallet. Never strike directly with a metal hammer to prevent splintering the wood! 🪵",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                } else {
                    return TutorResponse.fromModelOutput(
                        "Tool recommendation: Select a matching driver bit (PH2/PZ2 for cross-head, or appropriate Hex key) to ensure full engagement and prevent stripping the fastener head. 🛠️",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                }
            }
            
            // 7. Universal Physical Assembly: Joint Alignment & Squareness
            if lower.contains("square") || lower.contains("flush") || lower.contains("joint aligned") || lower.contains("corner") || lower.contains("misaligned") {
                return TutorResponse.fromModelOutput(
                    "Joint alignment rule: Align workpiece surfaces until completely flush with zero gap before tightening. Check that perpendicular panels form a true 90° angle within 5° tolerance! 📐",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 8. Universal Physical Assembly: Kinematics & Belts
            if lower.contains("belt") || lower.contains("tension") || lower.contains("gear") || lower.contains("bearing") || lower.contains("backlash") {
                if lower.contains("belt") || lower.contains("tension") {
                    return TutorResponse.fromModelOutput(
                        "Belt tension: The timing belt should deflect ~5mm under moderate finger push or produce a low note (~100–120Hz) when plucked. Keep it parallel to rails without flange rubbing! ⚙️",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                } else if lower.contains("gear") {
                    return TutorResponse.fromModelOutput(
                        "Gear mesh rule: Set backlash to ~0.1mm–0.2mm. Try the paper slip test: a slip of printer paper should fold through the meshing teeth without tearing. ⚙️",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                } else {
                    return TutorResponse.fromModelOutput(
                        "Bearing installation: Apply press force ONLY to the outer ring when pressing into housings, or inner ring when pressing onto shafts. Never apply force across rolling balls! 🔄",
                        priority: .immediate,
                        category: "user_query_response",
                        inputTokens: inTokens
                    )
                }
            }
            
            // 9. Universal Physical Assembly: Fastener Count Verification
            if lower.contains("how many screw") || lower.contains("how many bolt") || lower.contains("screws left") || lower.contains("bolts left") || lower.contains("missing screw") {
                return TutorResponse.fromModelOutput(
                    "Fastener count check: Verify all required screws and bolts are placed in their respective mounting holes before locking the sub-assembly. No loose hardware should remain! 🔩",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
            
            // 6. Visual Verification Checks
            if lower.contains("look") || lower.contains("connect") || lower.contains("already") || lower.contains("check") {
                return TutorResponse.fromModelOutput(
                    "I'm focusing the camera directly on your workpiece right now! Keep your hands clear for just a moment with good lighting so I can inspect the pins and confirm the connection. 🔍",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            } else if lower.contains("where") || lower.contains("hole") || lower.contains("put") || lower.contains("slot") {
                return TutorResponse.fromModelOutput(
                    "Take a look at the green spatial target rings illuminated on your camera viewfinder—they show the exact coordinate sockets to plug into! 📍",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            } else if lower.contains("why") || lower.contains("reason") {
                return TutorResponse.fromModelOutput(
                    "This component is critical to complete the circuit path and ensure safe voltage levels so the board operates reliably. 💡",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            } else if lower.contains("right") || lower.contains("done") || lower.contains("good") {
                return TutorResponse.fromModelOutput(
                    "Inspecting the live video right now! Hold steady under the lens for one beat and let's lock this verification in. 🎯",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            } else {
                return TutorResponse.fromModelOutput(
                    "I'm right here in your workshop! Let's make sure this step is seated properly. Ask me anything or check the visual reticle on screen! 🛠️",
                    priority: .immediate,
                    category: "user_query_response",
                    inputTokens: inTokens
                )
            }
        }
    }
}
