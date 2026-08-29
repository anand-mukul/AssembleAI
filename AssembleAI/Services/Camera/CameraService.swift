//
//  CameraService.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Isolated camera service orchestrating `AVCaptureSession`, `AVCapturePhotoOutput`, authorization, and torch controls.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning: Bool = false
    @Published private(set) var isCameraAvailable: Bool = true
    @Published private(set) var isTorchSupported: Bool = false
    @Published var isTorchOn: Bool = false
    @Published var errorMessage: String? = nil
    
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let cameraQueue = DispatchQueue(label: "com.assembleai.cameraQueue")
    private var isConfigured = false
    
    private var photoContinuation: CheckedContinuation<UIImage, Error>? = nil
    
    override init() {
        super.init()
        checkPermission()
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
    
    /// Configures the AVCaptureSession with video input and photo output on a background queue.
    func configureSession() {
        guard !isConfigured else { return }
        
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            // Video Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                    self.errorMessage = "Camera unavailable (Simulator or hardware restriction)"
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.addInput(videoInput)
            
            // Photo Output
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
            }
            
            self.captureSession.commitConfiguration()
            
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
        
        cameraQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    /// Stops AVCaptureSession asynchronously.
    func stopSession() {
        cameraQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            
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
            
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            
            self.cameraQueue.async { [weak self] in
                guard let self = self else { return }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    /// Generates a synthetic test frame for Simulator testing.
    private func createSimulatorTestImage() -> UIImage {
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
