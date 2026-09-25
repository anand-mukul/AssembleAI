//
//  CameraPreviewView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// UIKit bridge wrapping `AVCaptureVideoPreviewLayer` for full-screen SwiftUI camera rendering.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var isRunning: Bool = false
    
    class VideoPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        private var startObserver: NSObjectProtocol?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupLayer()
        }
        
        deinit {
            if let observer = startObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        private func setupLayer() {
            backgroundColor = .clear
            videoPreviewLayer.videoGravity = .resizeAspectFill
            
            // Listen for session running notification to ensure preview layer connection is configured as soon as hardware streams
            startObserver = NotificationCenter.default.addObserver(
                forName: .AVCaptureSessionDidStartRunning,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshPreview()
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            refreshPreview()
        }
        
        func refreshPreview() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            videoPreviewLayer.frame = bounds
            if let connection = videoPreviewLayer.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if !connection.isEnabled {
                    connection.isEnabled = true
                }
            }
            CATransaction.commit()
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        view.videoPreviewLayer.session = session
        view.refreshPreview()
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.refreshPreview()
    }
}
