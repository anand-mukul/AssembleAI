//
//  CameraStreamingTests.swift
//  AssembleAITests
//

import XCTest
import CoreVideo
import AVFoundation
@testable import AssembleAI

final class CameraStreamingTests: XCTestCase {
    
    private var cameraService: CameraService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        cameraService = CameraService()
    }
    
    @MainActor
    override func tearDown() {
        cameraService = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Initial State & Diagnostics
    @MainActor
    func testCameraServiceInitialState() {
        XCTAssertFalse(cameraService.isSessionRunning)
        XCTAssertFalse(cameraService.isTorchOn)
        #if DEBUG
        XCTAssertEqual(cameraService.debugFramesReceived, 0)
        XCTAssertNil(cameraService.debugLastFrameTimestamp)
        #endif
    }
    
    // MARK: - Test 2: Frame Stream Creation & Async Lifetime
    func testFrameStreamCreationAndSubscription() async {
        let stream = await cameraService.frameStream
        
        let task = Task {
            for await pixelBuffer in stream {
                _ = CVPixelBufferGetWidth(pixelBuffer)
                break
            }
        }
        
        // Let the task register continuation and cancel cleanly
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        task.cancel()
        _ = await task.result
        
        XCTAssertTrue(task.isCancelled)
    }
    
    // MARK: - Test 3: Multiple Independent Stream Consumers
    func testMultipleFrameStreamConsumers() async {
        let stream1 = await cameraService.frameStream
        let stream2 = await cameraService.frameStream
        
        let task1 = Task {
            for await _ in stream1 { break }
        }
        let task2 = Task {
            for await _ in stream2 { break }
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        task1.cancel()
        task2.cancel()
        
        _ = await task1.result
        _ = await task2.result
        
        XCTAssertTrue(task1.isCancelled)
        XCTAssertTrue(task2.isCancelled)
    }
    
    // MARK: - Test 4: Simulator Synthetic PixelBuffer Generation
    @MainActor
    func testSimulatorPixelBufferGeneration() {
        let pixelBuffer = cameraService.createSimulatorPixelBuffer()
        
        XCTAssertNotNil(pixelBuffer, "Synthetic simulator pixel buffer should be non-nil")
        guard let buffer = pixelBuffer else { return }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
        
        XCTAssertEqual(width, 1084)
        XCTAssertEqual(height, 812)
        XCTAssertEqual(pixelFormat, kCVPixelFormatType_32BGRA)
    }
    
    // MARK: - Test 5: Photo Capture Fallback Preserved (Regression Guard)
    @MainActor
    func testSimulatorPhotoCaptureFallbackPreserved() async throws {
        let capturedImage = try await cameraService.capturePhoto()
        
        XCTAssertGreaterThan(capturedImage.size.width, 0)
        XCTAssertGreaterThan(capturedImage.size.height, 0)
    }
    
    // MARK: - Test 6: Stop Session Safety
    @MainActor
    func testStopSessionSafety() {
        cameraService.stopSession()
        XCTAssertFalse(cameraService.isSessionRunning)
    }
}
