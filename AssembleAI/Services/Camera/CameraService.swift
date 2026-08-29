//
//  CameraService.swift
//  AssembleAI
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

/// Isolated camera service orchestrating `AVCaptureSession`, permission authorization, and preview layer bindings.
@MainActor
final class CameraService: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning: Bool = false
    @Published private(set) var isCameraAvailable: Bool = true
    @Published var errorMessage: String? = nil
    
    let captureSession = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "com.assembleai.cameraQueue")
    private var isConfigured = false
    
    init() {
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
    
    /// Configures the AVCaptureSession on a dedicated background queue to prevent UI stalls.
    func configureSession() {
        guard !isConfigured else { return }
        
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
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
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isConfigured = true
                self.isCameraAvailable = true
            }
        }
    }
    
    /// Starts AVCaptureSession running asynchronously on the background camera queue.
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
}
