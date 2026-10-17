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

/// Strongly typed camera zoom factor option for UI rendering with deterministic identity.
struct CameraZoomOption: Identifiable, Sendable, Equatable {
    let id: String
    let factor: CGFloat
    let label: String
}

/// Isolated camera service orchestrating `AVCaptureSession`, `AVCapturePhotoOutput`, `AVCaptureVideoDataOutput`, authorization, and torch controls.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning: Bool = false
#if targetEnvironment(simulator)
    @Published private(set) var isCameraAvailable: Bool = false
#else
    @Published private(set) var isCameraAvailable: Bool = true
#endif
    @Published private(set) var isTorchSupported: Bool = false
    @Published var isTorchOn: Bool = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published private(set) var minZoomFactor: CGFloat = 0.5
    @Published private(set) var maxZoomFactor: CGFloat = 5.0
    @Published private(set) var availableZoomFactors: [CGFloat] = [0.5, 1.0, 2.0]
    @Published private(set) var availableZoomOptions: [CameraZoomOption] = [
        CameraZoomOption(id: "1x", factor: 1.0, label: "1×")
    ]
    @Published var errorMessage: String? = nil
    
    #if DEBUG
    @Published private(set) var debugFramesReceived: Int = 0
    @Published private(set) var debugLastFrameTimestamp: Date? = nil
    nonisolated private let debugCounter = DebugFrameCounter()
    #endif
    
    nonisolated let captureSession = AVCaptureSession()
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated private let cameraQueue = DispatchQueue(label: "com.mukul.assembleai.cameraQueue")
    nonisolated private let videoQueue = DispatchQueue(label: "com.mukul.assembleai.videoQueue", qos: .userInitiated)
    
    nonisolated private let broadcaster = FrameStreamBroadcaster()
    
    private var isConfiguring = false
    private var isConfigured = false
    private var activeDevice: AVCaptureDevice?
    private var photoContinuation: CheckedContinuation<UIImage, Error>? = nil
    private var simulatorFrameTask: Task<Void, Never>? = nil
    
    override init() {
        super.init()
        checkPermission()
        setupInterruptionObservers()
    }
    
    deinit {
        broadcaster.finishAll()
        simulatorFrameTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupInterruptionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: captureSession
        )
    }
    
    @objc private func handleSessionWasInterrupted(notification: Notification) {
        Task { @MainActor in
            self.isSessionRunning = false
            self.errorMessage = "Camera session interrupted"
        }
    }
    
    @objc private func handleSessionInterruptionEnded(notification: Notification) {
        Task { @MainActor in
            self.errorMessage = nil
            if self.authorizationStatus == .authorized {
                self.startSession()
            }
        }
    }
    
    // MARK: - Frame Stream API
    
    /// Asynchronous stream of video frames delivered as `CVPixelBuffer`.
    ///
    /// The stream uses `.bufferingNewest(1)` to guarantee bounded memory usage,
    /// dropping stale frames if downstream consumers process slower than the camera frame rate.
    nonisolated var frameStream: AsyncStream<CVPixelBuffer> {
        let broadcaster = self.broadcaster
        return AsyncStream(CVPixelBuffer.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            broadcaster.addContinuation(continuation, id: id)
            
            continuation.onTermination = { _ in
                broadcaster.removeContinuation(id: id)
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
    
    /// Configures the AVCaptureSession with multi-lens virtual devices, photo output, and video data output on a background queue.
    func configureSession() {
        guard !isConfigured, !isConfiguring else { return }
        isConfiguring = true
        
        cameraQueue.async { [weak self, captureSession, photoOutput, videoOutput, videoQueue] in
            guard let self = self else { return }
            
            captureSession.beginConfiguration()
            
            // Clean up any stale inputs and outputs before reconfiguring to prevent input collision
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            for output in captureSession.outputs {
                captureSession.removeOutput(output)
            }
            
            // Discovers the most capable multi-lens optical virtual device on modern iPhones down to single-lens fallback:
            // 1. .builtInTripleCamera (iPhone 11-16 Pro models with Ultra-Wide, Wide, Telephoto and automatic macro switching)
            // 2. .builtInDualWideCamera (standard iPhone 11-16 models with Ultra-Wide + Wide)
            // 3. .builtInDualCamera (older dual camera setups with Wide + Telephoto)
            // 4. .builtInWideAngleCamera (single-lens iPhone SE, XR, 8, etc.)
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .back
            )
            let videoDevice = discovery.devices.first ?? AVCaptureDevice.default(for: .video)
            
            guard let device = videoDevice,
                  let videoInput = try? AVCaptureDeviceInput(device: device),
                  captureSession.canAddInput(videoInput) else {
                
                DispatchQueue.main.async {
                    self.isConfiguring = false
                    #if targetEnvironment(simulator)
                    self.isCameraAvailable = false
                    self.errorMessage = "Simulator mode (optical simulation active)"
                    self.startSimulatorStreamIfNeeded()
                    #else
                    self.isCameraAvailable = false
                    self.errorMessage = "Unable to access optical hardware camera input. Check privacy settings."
                    #endif
                }
                captureSession.commitConfiguration()
                return
            }
            
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
                device.unlockForConfiguration()
            } catch {}
            
            captureSession.addInput(videoInput)
            
            if captureSession.canSetSessionPreset(.hd1920x1080) {
                captureSession.sessionPreset = .hd1920x1080
            } else if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            } else {
                captureSession.sessionPreset = .photo
            }
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                if let connection = photoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            if captureSession.canAddOutput(videoOutput) {
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                captureSession.addOutput(videoOutput)
                
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }
            
            captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.activeDevice = device
                self.isConfiguring = false
                self.isConfigured = true
                self.isCameraAvailable = true
                self.errorMessage = nil
                self.isTorchSupported = device.hasTorch
                self.minZoomFactor = device.minAvailableVideoZoomFactor
                self.maxZoomFactor = device.maxAvailableVideoZoomFactor
                
                var options: [CameraZoomOption] = []
                var factors: [CGFloat] = []
                
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = device.maxAvailableVideoZoomFactor
                
                if minZoom <= 0.6 {
                    let ultraFactor = max(minZoom, 0.5)
                    options.append(CameraZoomOption(id: "0.5x", factor: ultraFactor, label: "0.5×"))
                    factors.append(ultraFactor)
                }
                
                if minZoom <= 1.0 && maxZoom >= 1.0 {
                    options.append(CameraZoomOption(id: "1x", factor: 1.0, label: "1×"))
                    factors.append(1.0)
                }
                
                if maxZoom >= 2.0 {
                    options.append(CameraZoomOption(id: "2x", factor: 2.0, label: "2×"))
                    factors.append(2.0)
                }
                
                if maxZoom >= 5.0 {
                    options.append(CameraZoomOption(id: "5x", factor: 5.0, label: "5×"))
                    factors.append(5.0)
                } else if maxZoom >= 3.0 {
                    options.append(CameraZoomOption(id: "3x", factor: 3.0, label: "3×"))
                    factors.append(3.0)
                }
                
                if options.isEmpty {
                    options = [CameraZoomOption(id: "1x", factor: 1.0, label: "1×")]
                    factors = [1.0]
                }
                
                self.availableZoomOptions = options
                self.availableZoomFactors = factors
            }
        }
    }
    
    private func startSimulatorStreamIfNeeded() {
        guard !isCameraAvailable && isSessionRunning else { return }
        simulatorFrameTask?.cancel()
        simulatorFrameTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self, !Task.isCancelled else { break }
                if let buffer = self.createSimulatorPixelBuffer() {
                    self.broadcaster.broadcast(buffer)
                }
            }
        }
    }
    
    /// Starts AVCaptureSession running asynchronously.
    func startSession() {
        guard authorizationStatus == .authorized else {
            checkPermission()
            if authorizationStatus == .notDetermined {
                Task {
                    await requestPermission()
                }
            }
            return
        }
        
        if !isConfigured {
            configureSession()
        }
        
        #if targetEnvironment(simulator)
        if !isCameraAvailable {
            self.isSessionRunning = true
            startSimulatorStreamIfNeeded()
            return
        }
        #endif
        
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
        simulatorFrameTask?.cancel()
        simulatorFrameTask = nil
        
        if !isCameraAvailable {
            self.isSessionRunning = false
            return
        }
        
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
              let device = activeDevice ?? AVCaptureDevice.default(for: .video),
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
    
    /// Sets camera optical zoom factor smoothly with optional animated ramping.
    func setZoomFactor(_ factor: CGFloat, smooth: Bool = true) {
        guard isCameraAvailable else {
            self.zoomFactor = factor
            return
        }
        
        guard let device = activeDevice ?? AVCaptureDevice.default(for: .video) else {
            self.zoomFactor = factor
            return
        }
        
        do {
            try device.lockForConfiguration()
            let clampedFactor = max(device.minAvailableVideoZoomFactor, min(factor, min(device.maxAvailableVideoZoomFactor, 10.0)))
            if smooth && device.isRampingVideoZoom {
                device.cancelVideoZoomRamp()
            }
            if smooth {
                device.ramp(toVideoZoomFactor: clampedFactor, withRate: 16.0)
            } else {
                device.videoZoomFactor = clampedFactor
            }
            device.unlockForConfiguration()
            self.zoomFactor = clampedFactor
        } catch {
            self.errorMessage = "Could not set camera zoom factor"
        }
    }
    
    func capturePhoto() async throws -> UIImage {
        guard isCameraAvailable && isSessionRunning else {
            return createSimulatorTestImage()
        }
        
        guard photoContinuation == nil else {
            throw NSError(domain: "CameraService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Capture already in progress"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            
            self.cameraQueue.async { [weak self, photoOutput] in
                guard let self = self else { return }
                if let photoConnection = photoOutput.connection(with: .video), photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = .portrait
                }
                let settings = AVCapturePhotoSettings()
                if photoOutput.supportedFlashModes.contains(.auto) {
                    settings.flashMode = .auto
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    /// Generates a neutral test frame for Simulator testing without mock breadboards or placeholder labels.
    func createSimulatorTestImage() -> UIImage {
        let size = CGSize(width: 1084, height: 812)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            UIColor(white: 1.0, alpha: 0.15).setStroke()
            ctx.cgContext.setLineWidth(1.0)
            
            ctx.cgContext.move(to: CGPoint(x: center.x - 20, y: center.y))
            ctx.cgContext.addLine(to: CGPoint(x: center.x + 20, y: center.y))
            ctx.cgContext.move(to: CGPoint(x: center.x, y: center.y - 20))
            ctx.cgContext.addLine(to: CGPoint(x: center.x, y: center.y + 20))
            ctx.cgContext.strokePath()
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
        
        broadcaster.broadcast(pixelBuffer)
        
        #if DEBUG
        debugCounter.tick { count, now in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.debugFramesReceived = count
                self.debugLastFrameTimestamp = now
            }
        }
        #endif
    }
}

// MARK: - Thread-Safe Frame Stream Broadcaster

nonisolated private final class FrameStreamBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<CVPixelBuffer>.Continuation] = [:]
    
    nonisolated init() {}
    
    nonisolated func addContinuation(_ continuation: AsyncStream<CVPixelBuffer>.Continuation, id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        continuations[id] = continuation
    }
    
    nonisolated func removeContinuation(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        continuations.removeValue(forKey: id)
    }
    
    nonisolated func broadcast(_ pixelBuffer: CVPixelBuffer) {
        lock.lock()
        let active = Array(continuations.values)
        lock.unlock()
        
        for cont in active {
            cont.yield(pixelBuffer)
        }
    }
    
    nonisolated func finishAll() {
        lock.lock()
        let active = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()
        
        for cont in active {
            cont.finish()
        }
    }
}

#if DEBUG
nonisolated private final class DebugFrameCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int = 0
    private var lastReport = Date()
    
    nonisolated init() {}
    
    nonisolated func tick(onReport: (Int, Date) -> Void) {
        lock.lock()
        count += 1
        let now = Date()
        let shouldReport = count % 30 == 0 || now.timeIntervalSince(lastReport) >= 1.0
        if shouldReport {
            lastReport = now
            let c = count
            lock.unlock()
            onReport(c, now)
        } else {
            lock.unlock()
        }
    }
}
#endif


