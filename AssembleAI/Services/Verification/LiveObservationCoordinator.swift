//
//  LiveObservationCoordinator.swift
//  AssembleAI
//

import Foundation
import CoreGraphics

// MARK: - Live Observation Configuration

/// Configuration controlling stability windows and debounce thresholds for live verification.
public struct LiveObservationConfiguration: Sendable, Equatable {
    /// Number of consecutive matching observation comparisons required to confirm a state change (default: 2).
    public var consecutiveObservationsRequired: Int
    
    /// Minimum time in seconds a candidate state must persist before transitioning (default: 0.3s).
    public var minimumStateDurationSeconds: Double
    
    /// Minimum visual evidence confidence below which observations are treated as `.uncertain` (default: 0.50).
    public var minimumEvidenceConfidence: Double
    
    public init(
        consecutiveObservationsRequired: Int = 2,
        minimumStateDurationSeconds: Double = 0.3,
        minimumEvidenceConfidence: Double = 0.50
    ) {
        self.consecutiveObservationsRequired = max(1, consecutiveObservationsRequired)
        self.minimumStateDurationSeconds = max(0.0, minimumStateDurationSeconds)
        self.minimumEvidenceConfidence = max(0.1, min(1.0, minimumEvidenceConfidence))
    }
    
    /// Standard default live verification configuration.
    public static let `default` = LiveObservationConfiguration()
}

// MARK: - Live Observation Metrics

/// Performance and state diagnostics for live observation coordination.
public struct LiveObservationMetrics: Sendable, Equatable {
    public var observationsReceived: UInt64 = 0
    public var stateEstimationsPerformed: UInt64 = 0
    public var comparisonsPerformed: UInt64 = 0
    public var staleObservationsDiscarded: UInt64 = 0
    public var verificationsEmitted: UInt64 = 0
    public var currentStableStatus: ComparisonStatus? = nil
}

// MARK: - Live Observation Coordinator Protocol

/// Protocol orchestrating live computer vision observations, domain state estimation, and deterministic state comparison.
public protocol LiveObservationCoordinating: Sendable {
    /// Evaluates a single `VisualObservation` against an assembly step contract.
    func process(
        observation: VisualObservation,
        for step: AssemblyStep
    ) async -> VerificationResult?
    
    /// Creates an asynchronous stream of verified state results from an upstream observation stream.
    func liveVerificationStream(
        from observationStream: AsyncStream<VisualObservation>,
        stepProvider: @escaping @Sendable () -> AssemblyStep?
    ) -> AsyncStream<VerificationResult>
    
    /// Resets candidate state, stability counters, and metrics.
    func reset() async
    
    /// Retrieves current coordinator metrics.
    func getMetrics() async -> LiveObservationMetrics
}

// MARK: - Live Observation Coordinator Implementation

/// Actor-isolated orchestrator connecting `VisualObservation` stream to `AssemblyStateEstimator` and `AssemblyStateComparator`.
///
/// Enforces step identity validation, transient motion debounce, stale result protection, and duplicate emission filtering.
public actor LiveObservationCoordinator: LiveObservationCoordinating {
    private let estimator: AssemblyStateEstimating
    private let comparator: AssemblyStateComparator
    private var configuration: LiveObservationConfiguration
    
    private var metrics = LiveObservationMetrics()
    
    // Stability & Debounce Tracking
    private var candidateStatus: ComparisonStatus? = nil
    private var candidateCount: Int = 0
    private var candidateFirstSeenTime: Double = 0.0
    
    // Confirmed Stable State
    private var lastConfirmedStatus: ComparisonStatus? = nil
    private var lastEmittedResult: VerificationResult? = nil
    private var lastProcessedStepID: UUID? = nil
    
    public init(
        estimator: AssemblyStateEstimating = VisionAssemblyStateEstimator(),
        comparator: AssemblyStateComparator? = nil,
        configuration: LiveObservationConfiguration = .default
    ) {
        self.estimator = estimator
        self.configuration = configuration
        self.comparator = comparator ?? AssemblyStateComparator(
            configuration: VerificationConfiguration(
                minimumEvidenceConfidence: configuration.minimumEvidenceConfidence
            )
        )
    }
    
    // MARK: - Single Observation Processing
    
    /// Evaluates a single visual observation against the target assembly step.
    public func process(
        observation: VisualObservation,
        for step: AssemblyStep
    ) async -> VerificationResult? {
        metrics.observationsReceived += 1
        
        // Handle step transition: if step changed, reset stability counters
        if lastProcessedStepID != step.id {
            lastProcessedStepID = step.id
            resetStabilityCounters()
        }
        
        // 1. State Estimation: Convert low-level Vision observation into domain ObservedAssemblyState
        let observedState: ObservedAssemblyState
        do {
            observedState = try await estimator.estimate(observation: observation)
            metrics.stateEstimationsPerformed += 1
        } catch {
            // On estimation error, return safe uncertain fallback without crashing
            return nil
        }
        
        // 2. Expected State: Obtain step contract
        let expectedState = ExpectedAssemblyState.forStep(step)
        
        // 3. State Comparison: Run deterministic invariant checks
        let comparison = comparator.compare(expected: expectedState, observed: observedState)
        metrics.comparisonsPerformed += 1
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // 4. Stability Filter / Debounce: Prevent flickering during hand movement
        let isStable = evaluateStability(status: comparison.status, currentTime: currentTime)
        
        guard isStable else {
            return nil
        }
        
        // 5. Construct VerificationResult
        let result = createVerificationResult(
            from: comparison,
            expectedState: expectedState,
            observedState: observedState,
            step: step
        )
        
        // 6. Duplicate Verification Protection: Do not re-emit identical results
        if let last = lastEmittedResult,
           last.status == result.status,
           last.explanation == result.explanation {
            return nil
        }
        
        lastEmittedResult = result
        lastConfirmedStatus = comparison.status
        metrics.currentStableStatus = comparison.status
        metrics.verificationsEmitted += 1
        
        return result
    }
    
    // MARK: - Live Verification Stream
    
    /// Creates an asynchronous stream of verified state results from an upstream observation stream.
    public nonisolated func liveVerificationStream(
        from observationStream: AsyncStream<VisualObservation>,
        stepProvider: @escaping @Sendable () -> AssemblyStep?
    ) -> AsyncStream<VerificationResult> {
        AsyncStream(VerificationResult.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task { [weak self] in
                for await observation in observationStream {
                    guard !Task.isCancelled else { break }
                    guard let self = self else { break }
                    
                    // Capture current step identity at arrival
                    guard let currentStep = stepProvider() else { continue }
                    let stepID = currentStep.id
                    
                    // Process observation through state estimation and comparison
                    if let result = await self.process(observation: observation, for: currentStep) {
                        guard !Task.isCancelled else { break }
                        
                        // Stale Result Protection: Verify step did not change during async processing
                        guard let activeStep = stepProvider(), activeStep.id == stepID else {
                            await self.recordStaleDiscard()
                            continue
                        }
                        
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Reset & Metrics
    
    public func reset() {
        resetStabilityCounters()
        lastProcessedStepID = nil
        lastConfirmedStatus = nil
        lastEmittedResult = nil
        metrics = LiveObservationMetrics()
    }
    
    public func getMetrics() -> LiveObservationMetrics {
        metrics
    }
    
    private func recordStaleDiscard() {
        metrics.staleObservationsDiscarded += 1
    }
    
    // MARK: - Internal Helpers
    
    private func resetStabilityCounters() {
        candidateStatus = nil
        candidateCount = 0
        candidateFirstSeenTime = 0.0
    }
    
    private func evaluateStability(status: ComparisonStatus, currentTime: Double) -> Bool {
        if candidateStatus == status {
            candidateCount += 1
            let elapsedDuration = currentTime - candidateFirstSeenTime
            
            let countSatisfied = candidateCount >= configuration.consecutiveObservationsRequired
            let durationSatisfied = elapsedDuration >= configuration.minimumStateDurationSeconds
            
            return countSatisfied && durationSatisfied
        } else {
            // New candidate status
            candidateStatus = status
            candidateCount = 1
            candidateFirstSeenTime = currentTime
            
            // If only 1 observation is required with 0 duration, it is immediately stable
            return configuration.consecutiveObservationsRequired <= 1 && configuration.minimumStateDurationSeconds <= 0.0
        }
    }
    
    private func createVerificationResult(
        from comparison: StateComparison,
        expectedState: ExpectedAssemblyState,
        observedState: ObservedAssemblyState,
        step: AssemblyStep
    ) -> VerificationResult {
        let status: VerificationStatus
        switch comparison.status {
        case .correct:
            status = .correct
        case .incorrect:
            status = .incorrect
        case .uncertain:
            status = .uncertain
        }
        
        let explanationText: String
        if let primaryIssue = comparison.issues.first {
            explanationText = primaryIssue.explanation
        } else if status == .correct {
            explanationText = "All physical component relationships match the target step specification."
        } else {
            explanationText = "Could not determine placement confidence. Please ensure good lighting and clear camera framing."
        }
        
        let detectedDesc: String
        if observedState.detectedComponents.isEmpty {
            detectedDesc = "No components recognized in target workspace area."
        } else {
            detectedDesc = observedState.detectedComponents.map(\.name).joined(separator: ", ")
        }
        
        let expectedDesc: String
        if expectedState.requiredComponents.isEmpty {
            expectedDesc = step.title
        } else {
            expectedDesc = expectedState.requiredComponents.map(\.name).joined(separator: ", ")
        }
        
        return VerificationResult(
            status: status,
            confidence: comparison.confidence,
            detectedDescription: detectedDesc,
            expectedDescription: expectedDesc,
            explanation: explanationText
        )
    }
}
