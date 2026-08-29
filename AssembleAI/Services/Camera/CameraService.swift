//
//  CameraService.swift
//  AssembleAI
//

import Foundation
@preconcurrency import AVFoundation
import Combine
import CoreVideo
import SwiftUI
import UIKit

/// Isolated camera service orchestrating `AVCaptureSession`, `AVCapturePhotoOutput`, `AVCaptureVideoDataOutput`, authorization, and torch controls.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning: Bool = false
    @Published private(set) var isCameraAvailable: Bool = true
    @Published private(set) var isTorchSupported: Bool = false
    @Published var isTorchOn: Bool = false
    @Published var errorMessage: String? = nil
    
    #if DEBUG
    @Published private(set) var debugFramesReceived: Int = 0
    @Published private(set) var debugLastFrameTimestamp: Date? = nil
    #endif
    
    nonisolated let captureSession = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated private let cameraQueue = DispatchQueue(label: "com.assembleai.cameraQueue")
    nonisolated private let videoQueue = DispatchQueue(label: "com.assembleai.videoQueue", qos: .userInitiated)
    
    nonisolated private let streamLock = NSLock()
    nonisolated private var frameContinuations: [UUID: AsyncStream<CVPixelBuffer>.Continuation] = [:]
    
    private var isConfigured = false
    private var photoContinuation: CheckedContinuation<UIImage, Error>? = nil
    
    override init() {
        super.init()
        checkPermission()
    }
    
    deinit {
        streamLock.lock()
        let continuations = Array(frameContinuations.values)
        frameContinuations.removeAll()
        streamLock.unlock()
        for continuation in continuations {
            continuation.finish()
        }
    }
    
    // MARK: - Frame Stream API
    
    /// Asynchronous stream of video frames delivered as `CVPixelBuffer`.
    ///
    /// The stream uses `.bufferingNewest(1)` to guarantee bounded memory usage,
    /// dropping stale frames if downstream consumers process slower than the camera frame rate.
    nonisolated var frameStream: AsyncStream<CVPixelBuffer> {
        AsyncStream(CVPixelBuffer.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            self.streamLock.lock()
            self.frameContinuations[id] = continuation
            self.streamLock.unlock()
            
            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.streamLock.lock()
                self.frameContinuations.removeValue(forKey: id)
                self.streamLock.unlock()
            }
        }
    }
    
    /// Queries the current video authorization status.
    func checkPermission() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Asynchronously requests camera permission from iOS if not already determined.
    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        self.authorizationStatus = granted ? .authorized : .denied
        
        if granted {
            configureSession()
            startSession()
        }
    }
    
    /// Configures the AVCaptureSession with video input, photo output, and video data output on a background queue.
    func configureSession() {
        guard !isConfigured else { return }
        
        cameraQueue.async { [weak self, captureSession, photoOutput, videoOutput, videoQueue] in
            guard let self = self else { return }
            
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo
            
            // Video Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                    self.errorMessage = "Camera unavailable (Simulator or hardware restriction)"
                }
                captureSession.commitConfiguration()
                return
            }
            
            captureSession.addInput(videoInput)
            
            // Photo Output (for existing manual capture workflow)
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                if let maxDimensions = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
                    photoOutput.maxPhotoDimensions = maxDimensions
                }
            }
            
            // Video Data Output (for continuous Live Tutor observation stream)
            if captureSession.canAddOutput(videoOutput) {
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                captureSession.addOutput(videoOutput)
                
                if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            captureSession.commitConfiguration()
            
            let torchAvailable = videoDevice.hasTorch && videoDevice.isTorchAvailable
            
            DispatchQueue.main.async {
                self.isConfigured = true
                self.isCameraAvailable = true
                self.isTorchSupported = torchAvailable
            }
        }
    }
    
    /// Starts AVCaptureSession running asynchronously.
    func startSession() {
        guard authorizationStatus == .authorized else { return }
        
        if !isConfigured {
            configureSession()
        }
        
        cameraQueue.async { [weak self, captureSession] in
            guard let self = self, !captureSession.isRunning else { return }
            captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = captureSession.isRunning
            }
        }
    }
    
    /// Stops AVCaptureSession asynchronously.
    func stopSession() {
        cameraQueue.async { [weak self, captureSession] in
            guard let self = self, captureSession.isRunning else { return }
            captureSession.stopRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    /// Toggles hardware torch/flashlight state if supported by device.
    func toggleTorch() {
        guard isTorchSupported,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            let nextState = !isTorchOn
            device.torchMode = nextState ? .on : .off
            device.unlockForConfiguration()
            self.isTorchOn = nextState
        } catch {
            self.errorMessage = "Could not toggle torch mode"
        }
    }
    
    /// Captures a high-resolution photo from the active camera stream.
    func capturePhoto() async throws -> UIImage {
        guard isCameraAvailable && isSessionRunning else {
            // Fallback for Simulator mode: return a generated high-quality camera test frame
            return createSimulatorTestImage()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            
            self.cameraQueue.async { [weak self, photoOutput] in
                guard let self = self else { return }
                let settings = AVCapturePhotoSettings()
                if photoOutput.supportedFlashModes.contains(.auto) {
                    settings.flashMode = .auto
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    /// Generates a synthetic test frame for Simulator testing.
    func createSimulatorTestImage() -> UIImage {
        let size = CGSize(width: 1084, height: 812)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background PCB color
            UIColor(red: 0.08, green: 0.18, blue: 0.12, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Draw grid dots representing breadboard tie-points
            UIColor(white: 0.85, alpha: 0.6).setFill()
            for x in stride(from: 60, to: Int(size.width) - 60, by: 40) {
                for y in stride(from: 60, to: Int(size.height) - 60, by: 40) {
                    ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 8, height: 8))
                }
            }
            
            // Draw text marking "ATmega328P 10K 220" for Vision OCR testing
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let str = NSString(string: "AssembleAI Test Circuit — 220 OHM RESISTOR R1")
            str.draw(at: CGPoint(x: 100, y: 100), withAttributes: attrs)
        }
    }
    
    /// Generates a synthetic `CVPixelBuffer` for Simulator and test environments.
    func createSimulatorPixelBuffer() -> CVPixelBuffer? {
        let image = createSimulatorTestImage()
        guard let cgImage = image.cgImage else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let pxdata = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pxdata,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return buffer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                let continuation = self.photoContinuation
                self.photoContinuation = nil
                continuation?.resume(throwing: error)
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                let continuation = self.photoContinuation
                self.photoContinuation = nil
                continuation?.resume(throwing: NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't capture image"]))
            }
            return
        }
        
        Task { @MainActor in
            let continuation = self.photoContinuation
            self.photoContinuation = nil
            continuation?.resume(returning: image)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        streamLock.lock()
        let continuations = Array(frameContinuations.values)
        streamLock.unlock()
        
        for continuation in continuations {
            continuation.yield(pixelBuffer)
        }
        
        #if DEBUG
        let now = Date()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.debugFramesReceived += 1
            self.debugLastFrameTimestamp = now
        }
        #endif
    }
}

