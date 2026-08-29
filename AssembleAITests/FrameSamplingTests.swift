//
//  FrameSamplingTests.swift
//  AssembleAITests
//

import XCTest
import CoreMedia
import CoreVideo
import UIKit
@testable import AssembleAI

final class FrameSamplingTests: XCTestCase {
    
    private var samplingService: FrameSamplingService!
    
    override func setUp() async throws {
        try await super.setUp()
        samplingService = FrameSamplingService(
            configuration: FrameSamplingConfiguration(
                targetFramesPerSecond: 5.0,           // 200ms min interval
                motionThreshold: 0.05,
                rapidMotionThreshold: 0.30,
                stabilityWindowSeconds: 0.20,
                forcedHeartbeatIntervalSeconds: 2.0,
                gridSamplingDimension: 16
            )
        )
    }
    
    override func tearDown() async throws {
        samplingService = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: First Frame Acceptance
    func testFirstFrameAlwaysAccepted() async {
        let buffer = createTestPixelBuffer(color: .white)
        let timestamp = CMTime(seconds: 10.0, preferredTimescale: 600)
        
        let result = await samplingService.process(frame: buffer, timestamp: timestamp, priority: .normal)
        
        XCTAssertNotNil(result, "First frame should always be accepted")
        XCTAssertEqual(result?.sequenceNumber, 1)
        XCTAssertEqual(result?.motionDifference, 0.0)
        
        let metrics = await samplingService.getMetrics()
        XCTAssertEqual(metrics.framesReceived, 1)
        XCTAssertEqual(metrics.framesSampled, 1)
    }
    
    // MARK: - Test 2: Rate Gating (Time-based Interval)
    func testRateGatingRejectsTooRapidFrames() async {
        let buffer1 = createTestPixelBuffer(color: .white)
        let buffer2 = createTestPixelBuffer(color: .black)
        
        // Frame 1 at t = 10.0s (Accepted)
        let result1 = await samplingService.process(frame: buffer1, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        XCTAssertNotNil(result1)
        
        // Frame 2 at t = 10.05s (50ms later, below 200ms target interval -> Rejected by Rate Gate)
        let result2 = await samplingService.process(frame: buffer2, timestamp: CMTime(seconds: 10.05, preferredTimescale: 600))
        XCTAssertNil(result2, "Frame arriving before minimum interval should be dropped by rate gate")
        
        let metrics = await samplingService.getMetrics()
        XCTAssertEqual(metrics.framesDroppedByRate, 1)
    }
    
    // MARK: - Test 3: Motion Gating (Identical vs Changed Frames)
    func testMotionGatingRejectsStaticFrames() async {
        let whiteBuffer1 = createTestPixelBuffer(color: .white)
        let whiteBuffer2 = createTestPixelBuffer(color: .white)
        let blackBuffer = createTestPixelBuffer(color: .black)
        
        // Frame 1 at t = 10.0s
        _ = await samplingService.process(frame: whiteBuffer1, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        
        // Frame 2 at t = 10.3s (300ms later, rate passed, but identical image -> Dropped by Motion Gate)
        let staticResult = await samplingService.process(frame: whiteBuffer2, timestamp: CMTime(seconds: 10.3, preferredTimescale: 600))
        XCTAssertNil(staticResult, "Identical static frame should be dropped by motion gate")
        
        let metricsAfterStatic = await samplingService.getMetrics()
        XCTAssertEqual(metricsAfterStatic.framesDroppedByMotion, 1)
        
        // Frame 3 at t = 10.6s (Changed color to black -> Accepted)
        let changedResult = await samplingService.process(frame: blackBuffer, timestamp: CMTime(seconds: 10.6, preferredTimescale: 600))
        XCTAssertNotNil(changedResult, "Changed frame should pass motion gate")
        XCTAssertGreaterThan(changedResult?.motionDifference ?? 0, 0.5)
    }
    
    // MARK: - Test 4: Heartbeat Forced Sample
    func testHeartbeatForcesSampleOnStaticScene() async {
        let whiteBuffer1 = createTestPixelBuffer(color: .white)
        let whiteBuffer2 = createTestPixelBuffer(color: .white)
        
        // Frame 1 at t = 10.0s
        _ = await samplingService.process(frame: whiteBuffer1, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        
        // Frame 2 at t = 12.5s (2.5s later, exceeds 2.0s heartbeat interval -> Forced Sample Accepted)
        let heartbeatResult = await samplingService.process(frame: whiteBuffer2, timestamp: CMTime(seconds: 12.5, preferredTimescale: 600))
        XCTAssertNotNil(heartbeatResult, "Heartbeat interval should force sample even on static scene")
        XCTAssertEqual(heartbeatResult?.sequenceNumber, 2)
    }
    
    // MARK: - Test 5: Immediate Priority Override
    func testImmediatePriorityBypassesGates() async {
        let whiteBuffer1 = createTestPixelBuffer(color: .white)
        let whiteBuffer2 = createTestPixelBuffer(color: .white)
        
        // Frame 1 at t = 10.0s
        _ = await samplingService.process(frame: whiteBuffer1, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        
        // Frame 2 at t = 10.02s (20ms later + identical image), but with .immediate priority
        let immediateResult = await samplingService.process(
            frame: whiteBuffer2,
            timestamp: CMTime(seconds: 10.02, preferredTimescale: 600),
            priority: .immediate
        )
        
        XCTAssertNotNil(immediateResult, "Immediate priority should bypass rate and motion gates")
        XCTAssertEqual(immediateResult?.sequenceNumber, 2)
    }
    
    // MARK: - Test 6: Stability Gating (Rapid Motion Debounce)
    func testStabilityGatingDebouncesRapidMotion() async {
        let whiteBuffer = createTestPixelBuffer(color: .white)
        let blackBuffer = createTestPixelBuffer(color: .black)
        let grayBuffer = createTestPixelBuffer(color: .gray)
        
        // Frame 1 at t = 10.0s (White)
        _ = await samplingService.process(frame: whiteBuffer, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        
        // Frame 2 at t = 10.3s (Sudden massive change White -> Black: diff ~ 1.0 > rapidMotionThreshold 0.30)
        // Should trigger stability window and be dropped
        let rapidResult = await samplingService.process(frame: blackBuffer, timestamp: CMTime(seconds: 10.3, preferredTimescale: 600))
        XCTAssertNil(rapidResult, "Rapid motion should be dropped by stability gate")
        
        // Frame 3 at t = 10.4s (During 0.20s settling window -> Still dropped)
        let settlingResult = await samplingService.process(frame: grayBuffer, timestamp: CMTime(seconds: 10.4, preferredTimescale: 600))
        XCTAssertNil(settlingResult, "Frame during settling window should be dropped")
        
        // Frame 4 at t = 10.6s (Settling window passed -> Accepted!)
        let stabilizedResult = await samplingService.process(frame: grayBuffer, timestamp: CMTime(seconds: 10.6, preferredTimescale: 600))
        XCTAssertNotNil(stabilizedResult, "Stabilized frame after settling window should be accepted")
    }
    
    // MARK: - Test 7: Async Stream Pipeline & Cancellation
    func testAsyncStreamPipeline() async {
        let (sourceStream, sourceContinuation) = AsyncStream.makeStream(of: CVPixelBuffer.self)
        let sampledStream = await samplingService.sampledStream(from: sourceStream)
        
        let buffer1 = createTestPixelBuffer(color: .red)
        let buffer2 = createTestPixelBuffer(color: .blue)
        
        var receivedSamples: [SampledFrame] = []
        
        let consumerTask = Task {
            for await sampled in sampledStream {
                receivedSamples.append(sampled)
                if receivedSamples.count >= 2 {
                    break
                }
            }
        }
        
        // Yield frames to source stream
        sourceContinuation.yield(buffer1)
        try? await Task.sleep(nanoseconds: 250_000_000) // 250ms to exceed 200ms rate interval
        sourceContinuation.yield(buffer2)
        
        // Await consumer completion
        _ = await consumerTask.result
        sourceContinuation.finish()
        
        XCTAssertEqual(receivedSamples.count, 2)
        XCTAssertEqual(receivedSamples.first?.sequenceNumber, 1)
        XCTAssertEqual(receivedSamples.last?.sequenceNumber, 2)
    }
    
    // MARK: - Test 8: Reset Clears State
    func testResetClearsState() async {
        let buffer = createTestPixelBuffer(color: .white)
        _ = await samplingService.process(frame: buffer, timestamp: CMTime(seconds: 10.0, preferredTimescale: 600))
        
        var metrics = await samplingService.getMetrics()
        XCTAssertEqual(metrics.framesSampled, 1)
        
        await samplingService.reset()
        
        metrics = await samplingService.getMetrics()
        XCTAssertEqual(metrics.framesSampled, 0)
        XCTAssertEqual(metrics.framesReceived, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPixelBuffer(color: UIColor, size: CGSize = CGSize(width: 128, height: 128)) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to allocate test pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let pxdata = CVPixelBufferGetBaseAddress(buffer) else {
            fatalError("Failed to access base address")
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pxdata,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            fatalError("Failed to create CGContext")
        }
        
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return buffer
    }
}
