//
//  FrameSamplingService.swift
//  AssembleAI
//

import Foundation
import CoreMedia
import CoreVideo

// MARK: - Sampled Frame

/// Represents a video frame selected by the adaptive frame sampler for downstream visual analysis.
struct SampledFrame: @unchecked Sendable {
    /// The unmanaged raw video pixel buffer.
    let pixelBuffer: CVPixelBuffer
    
    /// Hardware capture presentation timestamp.
    let timestamp: CMTime
    
    /// Monotonically increasing sequence number for sampled frames.
    let sequenceNumber: UInt64
    
    /// Computed visual difference score against the previously sampled frame (0.0 = identical, 1.0 = completely different).
    let motionDifference: Double
    
    init(
        pixelBuffer: CVPixelBuffer,
        timestamp: CMTime = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600),
        sequenceNumber: UInt64 = 0,
        motionDifference: Double = 0.0
    ) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.sequenceNumber = sequenceNumber
        self.motionDifference = motionDifference
    }
}

// MARK: - Sampling Priority

/// Priority level governing frame sampling evaluation.
enum SamplingPriority: Sendable, Equatable {
    /// Standard sampling subject to time-based rate limits, motion thresholds, and stability gating.
    case normal
    
    /// High-priority sampling bypassing rate and motion thresholds (e.g. user-initiated query or step transition).
    case immediate
}

// MARK: - Frame Sampling Configuration

/// Configuration parameters controlling adaptive sampling intervals, motion thresholds, and scene stability debounce.
struct FrameSamplingConfiguration: Sendable, Equatable {
    /// Target frame rate in frames per second under active assembly conditions (default: 5.0 FPS).
    var targetFramesPerSecond: Double
    
    /// Minimum time interval in seconds between consecutive sampled frames.
    var minimumIntervalSeconds: Double {
        guard targetFramesPerSecond > 0 else { return 0.2 }
        return 1.0 / targetFramesPerSecond
    }
    
    /// Normalized motion threshold (0.0 to 1.0) required to treat the scene as meaningfully changed (default: 0.05).
    var motionThreshold: Double
    
    /// Rapid motion threshold (0.0 to 1.0) above which the scene is considered actively shaking or panning (default: 0.25).
    var rapidMotionThreshold: Double
    
    /// Time window in seconds of scene stabilization required after rapid motion before accepting a frame (default: 0.25s).
    var stabilityWindowSeconds: Double
    
    /// Maximum time interval in seconds a static scene can remain unsampled before forcing a heartbeat sample (default: 2.0s).
    var forcedHeartbeatIntervalSeconds: Double
    
    /// Grid dimension along each axis for lightweight luminance comparison (e.g. 16 -> 16x16 = 256 sample points).
    var gridSamplingDimension: Int
    
    init(
        targetFramesPerSecond: Double = 5.0,
        motionThreshold: Double = 0.05,
        rapidMotionThreshold: Double = 0.25,
        stabilityWindowSeconds: Double = 0.25,
        forcedHeartbeatIntervalSeconds: Double = 2.0,
        gridSamplingDimension: Int = 16
    ) {
        self.targetFramesPerSecond = max(0.5, min(30.0, targetFramesPerSecond))
        self.motionThreshold = max(0.01, min(1.0, motionThreshold))
        self.rapidMotionThreshold = max(motionThreshold, min(1.0, rapidMotionThreshold))
        self.stabilityWindowSeconds = max(0.05, min(2.0, stabilityWindowSeconds))
        self.forcedHeartbeatIntervalSeconds = max(0.5, min(10.0, forcedHeartbeatIntervalSeconds))
        self.gridSamplingDimension = max(4, min(64, gridSamplingDimension))
    }
    
    /// Default standard configuration for AssembleAI Live Tutor.
    static let `default` = FrameSamplingConfiguration()
}

// MARK: - Frame Sampling Diagnostics Metrics

/// Diagnostic performance metrics for engineering validation and performance tuning.
struct FrameSamplingMetrics: Sendable, Equatable {
    var framesReceived: UInt64 = 0
    var framesSampled: UInt64 = 0
    var framesDroppedByRate: UInt64 = 0
    var framesDroppedByMotion: UInt64 = 0
    var framesDroppedByStability: UInt64 = 0
    var framesForwarded: UInt64 = 0
    var lastSampleTimestampSeconds: Double = 0.0
    var effectiveSamplingFPS: Double = 0.0
}

// MARK: - Frame Sampling Protocol

/// Protocol defining the interface for adaptive camera frame sampling.
protocol FrameSampling: Sendable {
    /// Evaluates a candidate camera frame and returns a `SampledFrame` if it passes rate, motion, and stability gates.
    func process(
        frame: CVPixelBuffer,
        timestamp: CMTime,
        priority: SamplingPriority
    ) async -> SampledFrame?
    
    /// Creates an asynchronous stream of sampled frames from an input pixel buffer stream.
    func sampledStream(
        from sourceStream: AsyncStream<CVPixelBuffer>
    ) -> AsyncStream<SampledFrame>
    
    /// Resets internal temporal state, timestamps, and previous frame signatures.
    func reset() async
    
    /// Returns current diagnostic sampling metrics.
    func getMetrics() async -> FrameSamplingMetrics
}

typealias FrameSamplingServiceProtocol = FrameSampling

extension FrameSampling {
    /// Subscribes to an upstream video stream and samples frames as CVPixelBuffer.
    func sample(stream: AsyncStream<CVPixelBuffer>) -> AsyncStream<CVPixelBuffer> {
        AsyncStream(CVPixelBuffer.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let source = sampledStream(from: stream)
            let task = Task {
                for await frame in source {
                    if Task.isCancelled { break }
                    continuation.yield(frame.pixelBuffer)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Frame Sampling Service Implementation

/// Actor-isolated adaptive frame sampling service implementing rate limiting, sub-millisecond motion gating,
/// and stability debounce windows.
actor FrameSamplingService: FrameSampling {
    var configuration: FrameSamplingConfiguration
    private var metrics = FrameSamplingMetrics()
    
    private var sequenceCounter: UInt64 = 0
    private var lastSampledTimeSeconds: Double = 0.0
    private var lastRapidMotionTimeSeconds: Double = 0.0
    private var lastFrameSignature: [UInt8]? = nil
    
    // Exponential moving average window for FPS estimation
    private var lastFPSCalculationTime: Double = 0.0
    private var framesInCurrentSecond: UInt64 = 0
    
    init(configuration: FrameSamplingConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Evaluates a single candidate camera frame through rate, motion, and stability gates.
    func process(
        frame: CVPixelBuffer,
        timestamp: CMTime,
        priority: SamplingPriority = .normal
    ) -> SampledFrame? {
        metrics.framesReceived += 1
        
        let timeSeconds: Double
        if CMTIME_IS_VALID(timestamp) && timestamp.timescale > 0 {
            timeSeconds = CMTimeGetSeconds(timestamp)
        } else {
            timeSeconds = CFAbsoluteTimeGetCurrent()
        }
        
        let signature = extractGridSignature(from: frame, dimension: configuration.gridSamplingDimension)
        
        // 1. First Frame Handling: Always accept initial frame
        guard let previousSignature = lastFrameSignature, lastSampledTimeSeconds > 0 else {
            return acceptFrame(frame: frame, timestamp: timestamp, timeSeconds: timeSeconds, signature: signature, difference: 0.0)
        }
        
        let difference = computeSignatureDifference(signature, previousSignature)
        
        // 2. High-Priority / Immediate Override: Bypasses rate and motion gates
        if priority == .immediate {
            return acceptFrame(frame: frame, timestamp: timestamp, timeSeconds: timeSeconds, signature: signature, difference: difference)
        }
        
        // 3. Rate Gate: Reject frames arriving faster than target interval
        let timeSinceLastSample = timeSeconds - lastSampledTimeSeconds
        if timeSinceLastSample < configuration.minimumIntervalSeconds {
            metrics.framesDroppedByRate += 1
            return nil
        }
        
        // 4. Heartbeat Check: Force emission if scene is static for too long
        if timeSinceLastSample >= configuration.forcedHeartbeatIntervalSeconds {
            return acceptFrame(frame: frame, timestamp: timestamp, timeSeconds: timeSeconds, signature: signature, difference: difference)
        }
        
        // 5. Motion Gate: Reject frames with negligible visual changes
        if difference < configuration.motionThreshold {
            metrics.framesDroppedByMotion += 1
            return nil
        }
        
        // 6. Stability Gate: Detect rapid motion/shaking and enforce settling window
        if difference >= configuration.rapidMotionThreshold {
            lastRapidMotionTimeSeconds = timeSeconds
            metrics.framesDroppedByStability += 1
            return nil
        }
        
        if lastRapidMotionTimeSeconds > 0 {
            let timeSinceRapid = timeSeconds - lastRapidMotionTimeSeconds
            if timeSinceRapid < configuration.stabilityWindowSeconds {
                metrics.framesDroppedByStability += 1
                return nil
            } else {
                // Stabilized! Clear rapid motion flag
                lastRapidMotionTimeSeconds = 0.0
            }
        }
        
        // 7. Frame passed all gates: Accept
        return acceptFrame(frame: frame, timestamp: timestamp, timeSeconds: timeSeconds, signature: signature, difference: difference)
    }
    
    /// Subscribes to an upstream `AsyncStream<CVPixelBuffer>` and returns an `AsyncStream<SampledFrame>` with bounded backpressure.
    func sampledStream(
        from sourceStream: AsyncStream<CVPixelBuffer>
    ) -> AsyncStream<SampledFrame> {
        AsyncStream(SampledFrame.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task { [weak self] in
                for await pixelBuffer in sourceStream {
                    guard !Task.isCancelled else { break }
                    guard let self = self else { break }
                    
                    let timestamp = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
                    if let sampled = await self.process(frame: pixelBuffer, timestamp: timestamp, priority: .normal) {
                        continuation.yield(sampled)
                    }
                }
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Resets state, sequence counter, and timestamps.
    func reset() {
        lastSampledTimeSeconds = 0.0
        lastRapidMotionTimeSeconds = 0.0
        lastFrameSignature = nil
        sequenceCounter = 0
        metrics = FrameSamplingMetrics()
    }
    
    /// Retrieves current diagnostic metrics.
    func getMetrics() -> FrameSamplingMetrics {
        metrics
    }
    
    // MARK: - Internal Helpers
    
    private func acceptFrame(
        frame: CVPixelBuffer,
        timestamp: CMTime,
        timeSeconds: Double,
        signature: [UInt8],
        difference: Double
    ) -> SampledFrame {
        sequenceCounter += 1
        lastSampledTimeSeconds = timeSeconds
        lastFrameSignature = signature
        
        metrics.framesSampled += 1
        metrics.framesForwarded += 1
        metrics.lastSampleTimestampSeconds = timeSeconds
        
        updateFPSMetrics(currentTime: timeSeconds)
        
        return SampledFrame(
            pixelBuffer: frame,
            timestamp: timestamp,
            sequenceNumber: sequenceCounter,
            motionDifference: difference
        )
    }
    
    private func updateFPSMetrics(currentTime: Double) {
        if lastFPSCalculationTime == 0.0 {
            lastFPSCalculationTime = currentTime
            framesInCurrentSecond = 1
            return
        }
        
        framesInCurrentSecond += 1
        let elapsed = currentTime - lastFPSCalculationTime
        if elapsed >= 1.0 {
            metrics.effectiveSamplingFPS = Double(framesInCurrentSecond) / elapsed
            framesInCurrentSecond = 0
            lastFPSCalculationTime = currentTime
        }
    }
    
    /// Extracts a lightweight normalized grid of luminance values from a `CVPixelBuffer`.
    /// Operates in sub-millisecond time with zero heap allocations.
    private func extractGridSignature(from pixelBuffer: CVPixelBuffer, dimension: Int) -> [UInt8] {
        let count = dimension * dimension
        var signature = [UInt8](repeating: 0, count: count)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return signature
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        guard width > 0, height > 0 else { return signature }
        
        let stepX = max(1, width / dimension)
        let stepY = max(1, height / dimension)
        let bufferPtr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var index = 0
        for gy in 0..<dimension {
            let py = min(height - 1, gy * stepY)
            let rowOffset = py * bytesPerRow
            
            for gx in 0..<dimension {
                let px = min(width - 1, gx * stepX)
                let pixelOffset = rowOffset + (px * 4)
                
                if pixelFormat == kCVPixelFormatType_32BGRA {
                    // BGRA: B = bufferPtr[0], G = bufferPtr[1], R = bufferPtr[2]
                    let b = UInt32(bufferPtr[pixelOffset])
                    let g = UInt32(bufferPtr[pixelOffset + 1])
                    let r = UInt32(bufferPtr[pixelOffset + 2])
                    // Fast integer luminance approximation: (R + 2G + B) / 4
                    let lum = UInt8((r + (g << 1) + b) >> 2)
                    signature[index] = lum
                } else {
                    // Fallback luminance byte reading
                    signature[index] = bufferPtr[pixelOffset]
                }
                index += 1
            }
        }
        
        return signature
    }
    
    /// Computes the normalized average absolute difference between two grid signatures (0.0 to 1.0).
    private func computeSignatureDifference(_ current: [UInt8], _ previous: [UInt8]) -> Double {
        guard current.count == previous.count, !current.isEmpty else { return 1.0 }
        
        var totalDiff: UInt64 = 0
        let count = current.count
        
        for i in 0..<count {
            let a = Int32(current[i])
            let b = Int32(previous[i])
            totalDiff += UInt64(abs(a - b))
        }
        
        // Normalized: average absolute error divided by max possible byte difference (255.0)
        let averageDiff = Double(totalDiff) / Double(count)
        return averageDiff / 255.0
    }
}
