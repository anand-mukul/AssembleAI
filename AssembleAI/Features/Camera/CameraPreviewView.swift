//
//  CameraPreviewView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// UIKit bridge wrapping `AVCaptureVideoPreviewLayer` for full-screen SwiftUI camera rendering.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class VideoPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}
