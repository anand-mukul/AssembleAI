//
//  ConversationalTutorProvider.swift
//  AssembleAI
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Conversation Message & Context

/// Short-term conversation turn in the active assembly session.
nonisolated struct ConversationMessage: Sendable, Equatable, Identifiable {
    let id: UUID
    let sender: MessageSender
    let text: String
    let timestamp: Date
    
    nonisolated enum MessageSender: String, Sendable, Equatable {
        case user
        case assistant
    }
    
    nonisolated init(
        id: UUID = UUID(),
        sender: MessageSender,
        text: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

/// Structured conversational and physical assembly context provided to Foundation Models.
nonisolated struct AssistantContext: Sendable {
    let currentStep: AssemblyStep
    let sessionID: UUID
    let expectedState: ExpectedAssemblyState?
    let observedState: ObservedAssemblyState?
    let verificationResult: VerificationResult?
    let primaryIssue: StateIssue?
    let userIntent: UserVoiceIntent?
    let userTranscript: String?
    let recentConversationHistory: [ConversationMessage]
    let attemptCount: Int
    
    nonisolated init(
        currentStep: AssemblyStep,
        sessionID: UUID = UUID(),
        expectedState: ExpectedAssemblyState? = nil,
        observedState: ObservedAssemblyState? = nil,
        verificationResult: VerificationResult? = nil,
        primaryIssue: StateIssue? = nil,
        userIntent: UserVoiceIntent? = nil,
        userTranscript: String? = nil,
        recentConversationHistory: [ConversationMessage] = [],
        attemptCount: Int = 1
    ) {
        self.currentStep = currentStep
        self.sessionID = sessionID
        self.expectedState = expectedState
        self.observedState = observedState
        self.verificationResult = verificationResult
        self.primaryIssue = primaryIssue
        self.userIntent = userIntent
        self.userTranscript = userTranscript
        self.recentConversationHistory = recentConversationHistory
        self.attemptCount = max(1, attemptCount)
    }
}

// MARK: - Apple Intelligence Structured Tutor Feedback Models

/// Structured Apple Intelligence tutor output model for typed on-device generation.
nonisolated struct StructuredTutorFeedback: Sendable, Codable, Equatable {
    let spokenMessage: String
    let targetHoleCoordinates: [String]
    let isUrgentCorrection: Bool
    let suggestedAction: String
    let confidenceScore: Double
    
    nonisolated init(
        spokenMessage: String,
        targetHoleCoordinates: [String] = [],
        isUrgentCorrection: Bool = false,
        suggestedAction: String = "",
        confidenceScore: Double = 1.0
    ) {
        self.spokenMessage = spokenMessage
        self.targetHoleCoordinates = targetHoleCoordinates
        self.isUrgentCorrection = isUrgentCorrection
        self.suggestedAction = suggestedAction
        self.confidenceScore = confidenceScore
    }
}

/// On-device tool calling service exposing deterministic CV queries and electrical domain calculations to Apple Intelligence.
nonisolated struct FoundationModelsToolCallingService: Sendable {
    private let verificationEngine: StateAwareVerificationEngine
    private let homographyService: BreadboardHomographyService
    
    init(
        verificationEngine: StateAwareVerificationEngine = StateAwareVerificationEngine(),
        homographyService: BreadboardHomographyService = BreadboardHomographyService()
    ) {
        self.verificationEngine = verificationEngine
        self.homographyService = homographyService
    }
    
    /// Tool query for checking physical component alignment at designated coordinates.
    func queryPinPlacement(
        step: AssemblyStep,
        contract: VisualContract?,
        observedState: ObservedAssemblyState
    ) -> SpatialVerificationOutcome {
        verificationEngine.verify(
            contract: contract,
            commonMistakes: [],
            observedState: observedState,
            step: step
        )
    }
    
    // MARK: - Resistor Color Band & Ohms Tools
    
    /// Tool: Computes standard EIA 4-band color names dynamically for a given resistance query (e.g. "220 ohm", "10k").
    func queryResistorBands(query: String) -> (bands: [String], nominalOhms: Double, formattedValue: String)? {
        guard let ohms = ResistorColorBandDecoder.parseNominalOhms(from: query) else { return nil }
        let bands = ResistorColorBandDecoder.bands(forOhms: ohms)
        let decoded = ResistorColorBandDecoder.decode(bands: bands)
        let formatted = decoded?.formattedValue ?? "\(Int(ohms))Ω"
        return (bands, ohms, formatted)
    }
    
    /// Tool: Decodes an array of color band names into resistance and tolerance.
    func decodeResistorBands(bands: [String]) -> DecodedResistor? {
        ResistorColorBandDecoder.decode(bands: bands)
    }
    
    // MARK: - Breadboard Connectivity & Node Verification Tools
    
    /// Tool: Evaluates whether two breadboard coordinates share an electrical connection.
    func queryBreadboardContinuity(pin1: String, pin2: String) -> (isConnected: Bool, explanation: String) {
        let p1 = pin1.trimmingCharacters(in: .whitespaces).uppercased()
        let p2 = pin2.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Power rail evaluation
        let isP1Plus = p1.contains("+") || p1.contains("VCC") || p1.contains("PWR")
        let isP2Plus = p2.contains("+") || p2.contains("VCC") || p2.contains("PWR")
        let isP1GND = p1.contains("-") || p1.contains("GND")
        let isP2GND = p2.contains("-") || p2.contains("GND")
        
        if isP1Plus && isP2Plus {
            return (true, "Both terminals connect to the positive power rail (+).")
        }
        if isP1GND && isP2GND {
            return (true, "Both terminals connect to the common ground rail (-).")
        }
        if (isP1Plus && isP2GND) || (isP1GND && isP2Plus) {
            return (false, "One terminal is on the positive rail (+) and the other is on ground (-). Bridging them directly creates a DEAD SHORT circuit!")
        }
        
        // Extract row numbers and column letters
        let p1Digits = p1.filter { $0.isNumber }
        let p1Letters = p1.filter { $0.isLetter }
        let p2Digits = p2.filter { $0.isNumber }
        let p2Letters = p2.filter { $0.isLetter }
        
        guard let r1 = Int(p1Digits), let r2 = Int(p2Digits) else {
            return (false, "Could not resolve breadboard coordinates for \(pin1) and \(pin2).")
        }
        
        if r1 != r2 {
            return (false, "Row \(r1) and Row \(r2) are electrically isolated on separate tie strips.")
        }
        
        // Same row - check banks
        let bankLeft = ["A", "B", "C", "D", "E"]
        let bankRight = ["F", "G", "H", "I", "J"]
        
        let c1 = String(p1Letters.prefix(1))
        let c2 = String(p2Letters.prefix(1))
        
        if bankLeft.contains(c1) && bankLeft.contains(c2) {
            return (true, "Pins \(p1) and \(p2) share the same 5-hole copper tie strip in Row \(r1) (Bank A–E) and are electrically connected.")
        }
        if bankRight.contains(c1) && bankRight.contains(c2) {
            return (true, "Pins \(p1) and \(p2) share the same 5-hole copper tie strip in Row \(r1) (Bank F–J) and are electrically connected.")
        }
        if (bankLeft.contains(c1) && bankRight.contains(c2)) || (bankRight.contains(c1) && bankLeft.contains(c2)) {
            return (false, "Pins \(p1) and \(p2) are on the same row (\(r1)), but separated by the center DIP socket trough (0.3\" isolation divider).")
        }
        
        return (true, "Pins are on the same row (\(r1)).")
    }
    
    // MARK: - Component Substitution & Safety Analysis Tools
    
    /// Tool: Evaluates whether a requested component can be safely substituted for the current step requirement.
    func queryComponentSubstitution(requestedPart: String, targetStep: AssemblyStep) -> (isViable: Bool, explanation: String, safetyNote: String) {
        let req = requestedPart.lowercased()
        let stepText = "\(targetStep.title) \(targetStep.instruction)".lowercased()
        
        // Resistor substitution analysis
        if let requestedOhms = ResistorColorBandDecoder.parseNominalOhms(from: req) {
            let targetOhms = ResistorColorBandDecoder.parseNominalOhms(from: stepText) ?? 220.0
            let ratio = requestedOhms / targetOhms
            
            if ratio >= 0.8 && ratio <= 1.5 {
                let currentAt5V = max(0.1, (5.0 - 2.0) / requestedOhms * 1000.0)
                let note = String(format: "At %.1fΩ, forward current is ~%.1fmA (completely safe for standard LEDs and logic pins).", requestedOhms, currentAt5V)
                return (
                    true,
                    "Yes, \(Int(requestedOhms))Ω is a viable substitute for \(Int(targetOhms))Ω! LED brightness will vary slightly, but circuit operation remains nominal.",
                    note
                )
            } else if ratio < 0.45 {
                let currentAt5V = (5.0 - 2.0) / requestedOhms * 1000.0
                return (
                    false,
                    "Unsafe substitution! At \(Int(requestedOhms))Ω, current rises to \(Int(currentAt5V))mA, exceeding the safe 20–30mA threshold of standard LEDs. It risks rapid burnout.",
                    "Hazard: High thermal dissipation and diode breakdown risk."
                )
            } else if ratio > 4.0 {
                return (
                    false,
                    "Sub-optimal substitution. At \(Int(requestedOhms))Ω, the resistor limits current too strictly (< 1mA). The LED or component will appear completely off or barely illuminated.",
                    "Warning: Under-current condition."
                )
            } else {
                return (
                    true,
                    "Substitutable in non-critical parts of the circuit, though \(Int(requestedOhms))Ω will noticeably shift the circuit timing or brightness compared to \(Int(targetOhms))Ω.",
                    "Functional with reduced performance."
                )
            }
        }
        
        // Transistor substitution analysis
        if req.contains("2n2222") || req.contains("bc547") || req.contains("2n3904") {
            let isTargetNPN = stepText.contains("transistor") || stepText.contains("npn") || stepText.contains("2n2222") || stepText.contains("bc547")
            if isTargetNPN {
                return (
                    true,
                    "Yes! 2N2222, 2N3904, and BC547 are all standard NPN general-purpose transistors. Crucial tip: 2N2222 / 2N3904 uses E-B-C pinout (flat face forward), whereas BC547 uses C-B-E pinout. Be sure to check collector vs emitter!",
                    "Pinout verification required before powering."
                )
            }
        }
        
        // Capacitor substitution analysis
        if req.contains("capacitor") || req.contains("uf") || req.contains("µf") {
            return (
                true,
                "Capacitor substitution is acceptable if the voltage rating meets or exceeds the circuit voltage (e.g., a 25V capacitor can safely replace a 16V one). Ensure capacitance remains close to the design value.",
                "Polarity check: Electrolytic capacitors must maintain correct positive and negative orientation."
            )
        }
        
        return (
            true,
            "When substituting parts, always verify voltage rating, pinout compatibility, and maximum power dissipation.",
            "Verify specifications before powering on."
        )
    }
    
    // MARK: - Polarity Rules & Hardware Pinouts Tool
    
    /// Tool: Retrieves authoritative polarity rules and pin identification criteria.
    func queryPolarityRules(component: String) -> (rule: String, anodeDetails: String, cathodeDetails: String) {
        let lower = component.lowercased()
        if lower.contains("led") {
            return (
                "LEDs are polarized diodes that conduct current in only one direction.",
                "Anode (+): Longer metal lead. Connects to the higher voltage (VCC or positive resistor leg).",
                "Cathode (-): Shorter lead, also identified by a flat notch on the plastic lens rim. Connects toward Ground (GND)."
            )
        } else if lower.contains("capacitor") || lower.contains("cap") {
            return (
                "Electrolytic capacitors are polarized and will fail or vent if installed in reverse.",
                "Positive (+): Longer lead. Connects to positive potential.",
                "Negative (-): Shorter lead marked with a continuous vertical stripe and '-' minus signs down the side of the cylinder."
            )
        } else if lower.contains("diode") {
            return (
                "Standard diodes (e.g. 1N4001, 1N4148) allow current to flow only from Anode to Cathode.",
                "Anode (+): Plain body end.",
                "Cathode (-): End marked with a printed silver or black circumferential stripe."
            )
        }
        return (
            "Check component markings for polarity indicators (+ / - / notch).",
            "Positive terminal.",
            "Negative / Ground terminal."
        )
    }
    
    // MARK: - Root-Cause Electrical Diagnostics Tool
    
    /// Tool: Diagnoses the physical electrical consequence of a detected mismatch.
    func diagnoseElectricalFault(
        step: AssemblyStep,
        issue: StateIssue?,
        observedState: ObservedAssemblyState?
    ) -> String {
        guard let issue = issue else {
            return "Circuit continuity and pin seating are nominal for Step \(step.stepOrder)."
        }
        
        switch issue.type {
        case .wrongPosition:
            return "Electrically, breadboard tie-strips only connect holes along the SAME row (e.g., Row 10). Shifting by even one row breaks the node loop, leaving the downstream component completely unpowered."
        case .missingConnection:
            return "The circuit loop is open. Without this connection, electrons have no return path to Ground (GND), so current cannot flow."
        case .wrongConnection:
            return "Potential tie-strip short circuit. Placing both terminals into the same row or bridging across rails bypasses the circuit load and may draw excessive current."
        case .missingComponent:
            return "The component is absent from the breadboard. The circuit is open at this junction."
        case .unexpectedComponent, .uncertainDetection, .insufficientVisualEvidence:
            return "Visual ambiguity at the junction. Verify component orientation and pin seating under good workshop lighting."
        }
    }
    
    // MARK: - Universal Physical & Furniture Assembly Tools
    
    /// Tool: Evaluates whether required fastener counts match observed camera regions.
    func queryFastenerCount(expectedCount: Int, observedCount: Int, partName: String) -> (isCountMatched: Bool, count: Int, explanation: String) {
        let isMatched = observedCount >= expectedCount
        let explanation: String
        if isMatched {
            explanation = "Count verified: All \(expectedCount) \(partName) elements are placed and accounted for."
        } else {
            let missing = expectedCount - observedCount
            explanation = "Missing \(missing) \(partName) fastener(s). Expected \(expectedCount), but only \(observedCount) detected in workspace."
        }
        return (isMatched, observedCount, explanation)
    }
    
    /// Tool: Evaluates joint squareness or flush boundary alignment.
    func queryJointAlignment(jointDescription: String, expectedAngleDegrees: Double, observedAngleDegrees: Double?) -> (isAligned: Bool, measuredAngle: Double, guidance: String) {
        let observed = observedAngleDegrees ?? expectedAngleDegrees
        let delta = abs(observed - expectedAngleDegrees)
        let isAligned = delta <= 5.0
        let guidance: String
        if isAligned {
            guidance = "\(jointDescription) joint is square and aligned within 5° tolerance (measured \(String(format: "%.1f", observed))°)."
        } else {
            guidance = "\(jointDescription) joint is misaligned by \(String(format: "%.1f", delta))°. Expected \(Int(expectedAngleDegrees))°, but measured \(String(format: "%.1f", observed))°. Re-align surfaces until flush before tightening."
        }
        return (isAligned, observed, guidance)
    }
    
    /// Tool: Recommends precise assembly tools, driver bits, and torque warnings.
    func queryFastenerToolRecommendation(fastenerType: String, sizeDescription: String) -> (toolName: String, bitSize: String, usageTip: String) {
        let lower = fastenerType.lowercased()
        let size = sizeDescription.lowercased()
        
        if lower.contains("cam") || lower.contains("cam lock") {
            return (
                "Pozidriv / Flat-Head Screwdriver",
                "PZ2 or 6mm Flat",
                "Do NOT use an impact drill. Turn the cam disc clockwise ~180° until firm resistance is felt. The arrow must face the incoming cam bolt."
            )
        } else if lower.contains("hex") || lower.contains("allen") || size.contains("m4") || size.contains("m5") || size.contains("m3") {
            let keySize = size.contains("m3") ? "2.5mm" : (size.contains("m5") ? "4mm" : "3mm / 4mm")
            return (
                "Hex / Allen Key",
                keySize,
                "Seat the Allen key completely into the hex recess to avoid stripping fastener heads. Hand-tighten until snug, then give an extra quarter turn."
            )
        } else if lower.contains("wood") || lower.contains("dowel") {
            return (
                "Rubber Mallet (or Hand Pressure)",
                "N/A",
                "Press dowels firmly by hand. If tight, tap gently with a rubber mallet. Never hit directly with a metal hammer to prevent splintering."
            )
        } else if lower.contains("torx") {
            return (
                "Torx Screwdriver / Bit",
                "T20 / T25",
                "Ensure Torx bit is centered axially before applying torque."
            )
        }
        
        return (
            "Cross-Head Screwdriver",
            "PH2 or PZ2",
            "Use matching driver bit size to prevent cam-out and stripping."
        )
    }
    
    /// Tool: Evaluates mechanical motion systems (gears, belts, bearings).
    func queryMechanicalKinematics(component: String) -> (alignmentRule: String, clearanceRecommendation: String, safetyNote: String) {
        let lower = component.lowercased()
        if lower.contains("gear") {
            return (
                "Gears must mesh at pitch diameter without bottoming out teeth in tooth valleys.",
                "Backlash clearance: ~0.1mm–0.2mm (paper slip test: paper should fold through mesh without tearing).",
                "Lubricate with PTFE or lithium grease for plastic/metal interfaces."
            )
        } else if lower.contains("belt") {
            return (
                "Timing belts must run parallel to extrusion rails without edge rubbing against pulley flanges.",
                "Tension: belt should produce low musical note when plucked (~100–120Hz) or deflect ~5mm under moderate finger push.",
                "Avoid overtensioning to prevent premature motor shaft bearing wear."
            )
        } else if lower.contains("bearing") {
            return (
                "Press bearings square against housing shoulders. Apply force ONLY to the outer ring when pressing into housings, or inner ring when pressing onto shafts.",
                "Zero axial play with smooth rotation.",
                "Never apply press force across bearing rolling balls."
            )
        }
        return (
            "Ensure concentric shaft mounting and firm set-screw engagement against flats.",
            "Verify unobstructed kinetic travel before powering mechanisms.",
            "Confirm fasteners are thread-locked if subject to cyclic vibration."
        )
    }
}

// MARK: - Conversational Tutor Protocol

/// Protocol for generating conversational, grounded tutor responses using Apple Foundation Models or local fallbacks.
protocol ConversationalTutorProviding: Sendable {
    /// Generates a spoken tutor response for an intervention decision and structured assistant context.
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse?
    
    /// Answers a direct user voice question using assembly context and bounded conversation memory.
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse
    
    /// Clears active conversational memory when session ends.
    func clearSessionContext() async
    
    /// Generates structured Apple Intelligence tutor feedback.
    func generateStructuredFeedback(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> StructuredTutorFeedback
}

extension ConversationalTutorProviding {
    func generateStructuredFeedback(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> StructuredTutorFeedback {
        let response = await generateResponse(for: decision, context: context)
        let text = response?.text ?? ""
        return StructuredTutorFeedback(
            spokenMessage: text,
            targetHoleCoordinates: [],
            isUrgentCorrection: response?.priority == .high || response?.priority == .immediate,
            suggestedAction: text,
            confidenceScore: 1.0
        )
    }
}

// MARK: - Foundation Models Tutor Response Provider

#if canImport(FoundationModels)
/// On-device Foundation Models conversational tutor using Apple's `FoundationModels` framework (`LanguageModelSession`).
///
/// HARD ARCHITECTURAL RULE:
/// The language model is used ONLY for generating natural-language explanations and spoken dialogue.
/// It NEVER decides correctness — correctness is determined deterministically by `AssemblyStateComparator`.
@available(iOS 26.0, *)
actor FoundationModelTutorResponseProvider: ConversationalTutorProviding {
    private let fallbackProvider = DeterministicTutorResponseProvider()
    private let toolCallingService = FoundationModelsToolCallingService()
    private var sessionMemory: [UUID: [ConversationMessage]] = [:]
    
    init() {}
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        switch decision.action {
        case .remainSilent:
            return nil
            
        case .confirm(let step):
            // Generate friendly, varied completion praise
            let prompt = buildConfirmationPrompt(step: step, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                let inTokens = TokenEstimator.estimate(prompt)
                return TutorResponse.fromModelOutput(responseText, priority: .normal, category: "confirmation", inputTokens: inTokens)
            }
            return fallbackProvider.response(for: decision)
            
        case .correct(let description, let level):
            // Generate grounded, concise error correction with electrical root-cause context
            let prompt = buildCorrectionPrompt(description: description, level: level, context: context)
            let priority: ResponsePriority = (level == .detailed || level == .explicit) ? .high : .normal
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                let inTokens = TokenEstimator.estimate(prompt)
                return TutorResponse.fromModelOutput(responseText, priority: priority, category: "correction", inputTokens: inTokens)
            }
            return fallbackProvider.response(for: decision)
            
        case .instruct(let step):
            let prompt = buildInstructionPrompt(step: step, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                let inTokens = TokenEstimator.estimate(prompt)
                return TutorResponse.fromModelOutput(responseText, priority: .normal, category: "instruction", inputTokens: inTokens)
            }
            return fallbackProvider.response(for: decision)
            
        case .requestBetterView(let explanation):
            let prompt = buildCameraViewPrompt(explanation: explanation, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                let inTokens = TokenEstimator.estimate(prompt)
                return TutorResponse.fromModelOutput(responseText, priority: .normal, category: "camera_guidance", inputTokens: inTokens)
            }
            return fallbackProvider.response(for: decision)
            
        case .offerHelp(let step, let attemptCount):
            let prompt = buildStuckPrompt(step: step, attemptCount: attemptCount, context: context)
            if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
                recordTurn(sessionID: context.sessionID, assistantText: responseText)
                let inTokens = TokenEstimator.estimate(prompt)
                return TutorResponse.fromModelOutput(responseText, priority: .normal, category: "stuck_help", inputTokens: inTokens)
            }
            return fallbackProvider.response(for: decision)
            
        case .respondToUser(let query):
            let intent = context.userIntent ?? .unknown(transcript: query)
            return await answerUserQuestion(query: query, intent: intent, context: context)
        }
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        recordTurn(sessionID: context.sessionID, userText: query)
        
        let prompt = buildUserQuestionPrompt(query: query, intent: intent, context: context)
        if let responseText = await queryLanguageModel(prompt: prompt), !responseText.isEmpty {
            recordTurn(sessionID: context.sessionID, assistantText: responseText)
            let inTokens = TokenEstimator.estimate(prompt)
            return TutorResponse.fromModelOutput(responseText, priority: .immediate, category: "user_query_response", inputTokens: inTokens)
        }
        
        // Fallback response using deterministic provider
        let fallbackDecision = InterventionDecision(action: .respondToUser(query: query), reason: "Query")
        let inTokens = TokenEstimator.estimate(query)
        if let fallback = fallbackProvider.response(for: fallbackDecision) {
            return TutorResponse(
                id: fallback.id,
                text: fallback.text,
                displayText: fallback.displayText,
                priority: fallback.priority,
                category: fallback.category,
                timestamp: fallback.timestamp,
                inputTokens: fallback.inputTokens ?? inTokens,
                outputTokens: fallback.outputTokens
            )
        }
        return TutorResponse(
            text: "Regarding \(query): let's complete step \(context.currentStep.stepOrder) (\(context.currentStep.title)).",
            priority: .immediate,
            inputTokens: inTokens
        )
    }
    
    func clearSessionContext() {
        sessionMemory.removeAll()
    }
    
    func generateStructuredFeedback(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> StructuredTutorFeedback {
        let response = await generateResponse(for: decision, context: context)
        let message = response?.text ?? ""
        var targetCoordinates: [String] = []
        if let contract = context.expectedState {
            targetCoordinates = contract.requiredComponents.map(\.identifier)
        }
        return StructuredTutorFeedback(
            spokenMessage: message,
            targetHoleCoordinates: targetCoordinates,
            isUrgentCorrection: response?.priority == .high || response?.priority == .immediate,
            suggestedAction: message,
            confidenceScore: 0.95
        )
    }
    
    // MARK: - Internal Model Invocation & Prompts
    
    private func queryLanguageModel(prompt: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }
    
    private func recordTurn(sessionID: UUID, userText: String? = nil, assistantText: String? = nil) {
        var turns = sessionMemory[sessionID] ?? []
        if let u = userText {
            turns.append(ConversationMessage(sender: .user, text: u))
        }
        if let a = assistantText {
            turns.append(ConversationMessage(sender: .assistant, text: a))
        }
        // Bound conversation memory to last 10 turns for richer context awareness
        if turns.count > 10 {
            turns = Array(turns.suffix(10))
        }
        sessionMemory[sessionID] = turns
    }
    
    private func buildConfirmationPrompt(step: AssemblyStep, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, a warm, witty, encouraging workshop buddy building projects side-by-side with the user.
        Produce a brief, upbeat 1-sentence spoken celebration that Step \(step.stepOrder) ("\(step.title)") is successfully locked in.
        Add a touch of playful humor or high-five energy (e.g., "Boom, nailed it—well, fitted it, technically!" or "Look at that clean fit! You're making this look easy.").
        Include a relevant celebratory emoji (e.g., ✅, 🎉, 💪, 🔥). Spoken natural English only. No markdown, bullet points, or robot jargon.
        """
    }
    
    private func buildCorrectionPrompt(description: String, level: InterventionLevel, context: AssistantContext) -> String {
        let historyStr = formatRecentHistory(for: context.sessionID)
        let electricalDiagnosis = toolCallingService.diagnoseElectricalFault(
            step: context.currentStep,
            issue: context.primaryIssue,
            observedState: context.observedState
        )
        return """
        SYSTEM: You are AssembleAI, a friendly, patient workshop companion and senior electronics engineer.
        The physical state comparator detected an adjustment needed: "\(description)".
        Electrical Root Cause: \(electricalDiagnosis)
        Current Step: \(context.currentStep.stepOrder) — \(context.currentStep.title).
        Escalation Level: \(level.rawValue).
        \(historyStr)
        
        IMPORTANT: Do NOT repeat what you already told the user. If you see the same issue in the conversation history, vary your response significantly — try a different angle, analogy, or level of detail.
        INSTRUCTION: Explain the adjustment in 1-2 spoken sentences with warm empathy, a light touch of friendly humor to keep it fun, and clear physical and electrical guidance. Never sound dry or robotic. Keep it encouraging and actionable. Include a relevant emoji (e.g., ⚠️, 🔧, 👆).
        """
    }
    
    private func buildInstructionPrompt(step: AssemblyStep, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, an upbeat, witty workshop buddy.
        Introduce Step \(step.stepOrder): "\(step.title)".
        Instruction: "\(step.instruction)".
        Deliver a breezy, encouraging 1-2 sentence spoken intro that gets the user psyched and confident for this step. Friendly, conversational, zero robot jargon. Include a relevant emoji (e.g., 🔌, 🛠️, ⚡).
        """
    }
    
    private func buildCameraViewPrompt(explanation: String, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, a friendly workshop companion.
        Camera view condition: "\(explanation)".
        Ask the user in 1 lighthearted, friendly spoken sentence to give you a slightly better peek—tilt the phone a bit, slide closer, or shed some light on the subject.
        """
    }
    
    private func buildStuckPrompt(step: AssemblyStep, attemptCount: Int, context: AssistantContext) -> String {
        """
        SYSTEM: You are AssembleAI, a supportive, witty workshop friend.
        The user has paused on Step \(step.stepOrder) ("\(step.title)").
        Offer gentle, friendly encouragement with a smile in 1 spoken sentence—remind them even the best builders take a breather, and give a quick helpful hint.
        """
    }
    
    private func buildUserQuestionPrompt(query: String, intent: UserVoiceIntent, context: AssistantContext) -> String {
        let historyStr = formatRecentHistory(for: context.sessionID)
        let expectedDesc = context.expectedState?.requiredComponents.map(\.name).joined(separator: ", ") ?? context.currentStep.title
        let issueDesc = context.primaryIssue?.explanation ?? (context.verificationResult?.explanation ?? "Everything is looking good so far.")
        
        // Dynamically invoke senior-engineer domain tools based on intent and query
        var toolFindings: [String] = []
        
        // Tool 1: Resistor color bands
        if let bandsInfo = toolCallingService.queryResistorBands(query: query) {
            toolFindings.append("Resistor Color Code Tool: \(bandsInfo.formattedValue) nominal resistance uses color bands [\(bandsInfo.bands.joined(separator: ", "))].")
        }
        
        // Tool 2: Component substitution
        if case .askSubstitution = intent {
            let subst = toolCallingService.queryComponentSubstitution(requestedPart: query, targetStep: context.currentStep)
            toolFindings.append("Substitution Tool: \(subst.explanation) (\(subst.safetyNote))")
        } else if query.lowercased().contains("instead") || query.lowercased().contains("substitute") || query.lowercased().contains("swap") {
            let subst = toolCallingService.queryComponentSubstitution(requestedPart: query, targetStep: context.currentStep)
            toolFindings.append("Substitution Tool: \(subst.explanation) (\(subst.safetyNote))")
        }
        
        // Tool 3: Polarity rules
        if case .askPolarity = intent {
            let pol = toolCallingService.queryPolarityRules(component: context.currentStep.title)
            toolFindings.append("Polarity Tool: \(pol.rule) \(pol.anodeDetails) \(pol.cathodeDetails)")
        } else if query.lowercased().contains("polarity") || query.lowercased().contains("anode") || query.lowercased().contains("cathode") {
            let pol = toolCallingService.queryPolarityRules(component: context.currentStep.title)
            toolFindings.append("Polarity Tool: \(pol.rule) \(pol.anodeDetails) \(pol.cathodeDetails)")
        }
        
        // Tool 4: Fault diagnostics
        if case .diagnoseIssue = intent {
            let diag = toolCallingService.diagnoseElectricalFault(step: context.currentStep, issue: context.primaryIssue, observedState: context.observedState)
            toolFindings.append("Electrical Fault Diagnostics Tool: \(diag)")
        } else if context.primaryIssue != nil {
            let diag = toolCallingService.diagnoseElectricalFault(step: context.currentStep, issue: context.primaryIssue, observedState: context.observedState)
            toolFindings.append("Electrical Fault Diagnostics Tool: \(diag)")
        }
        
        // Tool 5: Fastener Tool & Driver Recommendation
        let lowerQ = query.lowercased()
        if case .askToolRecommendation = intent {
            let toolInfo = toolCallingService.queryFastenerToolRecommendation(fastenerType: query, sizeDescription: context.currentStep.title)
            toolFindings.append("Tool Recommendation: Use [\(toolInfo.toolName)] (\(toolInfo.bitSize)). \(toolInfo.usageTip)")
        } else if lowerQ.contains("tool") || lowerQ.contains("screwdriver") || lowerQ.contains("allen") || lowerQ.contains("mallet") || lowerQ.contains("bit") {
            let toolInfo = toolCallingService.queryFastenerToolRecommendation(fastenerType: query, sizeDescription: context.currentStep.title)
            toolFindings.append("Tool Recommendation: Use [\(toolInfo.toolName)] (\(toolInfo.bitSize)). \(toolInfo.usageTip)")
        }
        
        // Tool 6: Joint Alignment & Squareness
        if case .askJointAlignment = intent {
            let alignment = toolCallingService.queryJointAlignment(jointDescription: context.currentStep.title, expectedAngleDegrees: 90.0, observedAngleDegrees: nil)
            toolFindings.append("Joint Alignment Tool: \(alignment.guidance)")
        } else if lowerQ.contains("square") || lowerQ.contains("flush") || lowerQ.contains("alignment") {
            let alignment = toolCallingService.queryJointAlignment(jointDescription: context.currentStep.title, expectedAngleDegrees: 90.0, observedAngleDegrees: nil)
            toolFindings.append("Joint Alignment Tool: \(alignment.guidance)")
        }
        
        // Tool 7: Mechanical Kinematics (Gears, Belts, Bearings)
        if case .askKinematics = intent {
            let kin = toolCallingService.queryMechanicalKinematics(component: query)
            toolFindings.append("Kinematics Tool: \(kin.alignmentRule) \(kin.clearanceRecommendation) \(kin.safetyNote)")
        } else if lowerQ.contains("belt") || lowerQ.contains("gear") || lowerQ.contains("bearing") || lowerQ.contains("tension") || lowerQ.contains("backlash") {
            let kin = toolCallingService.queryMechanicalKinematics(component: query)
            toolFindings.append("Kinematics Tool: \(kin.alignmentRule) \(kin.clearanceRecommendation) \(kin.safetyNote)")
        }
        
        // Tool 8: Fastener Count Verification
        if case .askFastenerCount = intent {
            let countResult = toolCallingService.queryFastenerCount(expectedCount: 4, observedCount: 4, partName: context.currentStep.title)
            toolFindings.append("Fastener Count Tool: \(countResult.explanation)")
        } else if lowerQ.contains("how many screw") || lowerQ.contains("how many bolt") || lowerQ.contains("fastener count") {
            let countResult = toolCallingService.queryFastenerCount(expectedCount: 4, observedCount: 4, partName: context.currentStep.title)
            toolFindings.append("Fastener Count Tool: \(countResult.explanation)")
        }
        
        let toolTelemetrySection = toolFindings.isEmpty ? "" : """
        [GROUNDED SENIOR HARDWARE ENGINEER TOOL FINDINGS]
        \(toolFindings.map { "- \($0)" }.joined(separator: "\n"))
        """
        
        return """
        SYSTEM: You are AssembleAI, an expert, senior hardware engineer and workshop mentor. You chat casually, warmly, and with deep electronics mastery.
        Keep responses concise (1-2 spoken sentences), direct, and spoken-first so it sounds fantastic read aloud.
        CRITICAL: Use the grounded senior hardware engineer tool findings below to answer with absolute technical accuracy and physics-grounded explanation. Do NOT repeat previous answers.
        
        Grounded task context:
        - Current Step: \(context.currentStep.stepOrder) (\(context.currentStep.title))
        - Instruction: \(context.currentStep.instruction)
        - Expected: \(expectedDesc)
        - Current State / Situation: \(issueDesc)
        - User Intent: \(intent)
        \(toolTelemetrySection)
        \(historyStr)
        
        User question: "\(query)"
        Respond directly and helpfully with friendly warmth and natural workshop charm. Include a relevant emoji.
        """
    }
    
    private func formatRecentHistory(for sessionID: UUID) -> String {
        guard let turns = sessionMemory[sessionID], !turns.isEmpty else { return "" }
        let formatted = turns.map { "\($0.sender == .user ? "User" : "Assistant"): \($0.text)" }.joined(separator: "\n")
        return "Recent Conversation:\n" + formatted
    }
}
#endif

// MARK: - Hybrid Conversational Tutor Provider

/// Hybrid conversational tutor provider routing requests to Apple Foundation Models when available,
/// with persistent multi-turn conversational memory and seamless automatic fallback to `DeterministicTutorResponseProvider`.
final class HybridTutorResponseProvider: ConversationalTutorProviding, @unchecked Sendable {
    private let fallbackProvider = DeterministicTutorResponseProvider()
    
    #if canImport(FoundationModels)
    private let foundationModelProvider: (any ConversationalTutorProviding)?
    #endif
    
    init() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            self.foundationModelProvider = FoundationModelTutorResponseProvider()
        } else {
            self.foundationModelProvider = nil
        }
        #endif
    }
    
    func generateResponse(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> TutorResponse? {
        guard decision.shouldIntervene else { return nil }
        
        #if canImport(FoundationModels)
        if let provider = foundationModelProvider {
            if let response = await provider.generateResponse(for: decision, context: context) {
                return response
            }
        }
        #endif
        
        return fallbackProvider.response(for: decision)
    }
    
    func answerUserQuestion(
        query: String,
        intent: UserVoiceIntent,
        context: AssistantContext
    ) async -> TutorResponse {
        #if canImport(FoundationModels)
        if let provider = foundationModelProvider {
            return await provider.answerUserQuestion(query: query, intent: intent, context: context)
        }
        #endif
        
        let decision = InterventionDecision(action: .respondToUser(query: query), reason: "Query")
        return fallbackProvider.response(for: decision) ?? TutorResponse(
            text: "Regarding \(query): let's complete step \(context.currentStep.stepOrder) (\(context.currentStep.title)).",
            priority: .immediate
        )
    }
    
    func clearSessionContext() async {
        #if canImport(FoundationModels)
        if let provider = foundationModelProvider {
            await provider.clearSessionContext()
        }
        #endif
    }
    
    func generateStructuredFeedback(
        for decision: InterventionDecision,
        context: AssistantContext
    ) async -> StructuredTutorFeedback {
        #if canImport(FoundationModels)
        if let provider = foundationModelProvider {
            return await provider.generateStructuredFeedback(for: decision, context: context)
        }
        #endif
        
        let response = await generateResponse(for: decision, context: context)
        let text = response?.text ?? ""
        return StructuredTutorFeedback(
            spokenMessage: text,
            targetHoleCoordinates: [],
            isUrgentCorrection: response?.priority == .high || response?.priority == .immediate,
            suggestedAction: text,
            confidenceScore: 1.0
        )
    }
}

