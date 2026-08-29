//
//  AssemblyCameraView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// Full-screen camera guidance experience featuring live AVCaptureSession preview, visual guidance overlays, reticles, and Analyze triggers.
struct AssemblyCameraView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var cameraService = CameraService()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let currentStep: AssemblyStep
    var activeGuidance: GuidanceOverlay? = nil
    var onAnalyze: ((UIImage?) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    
    @State private var reticleVisible = false
    @State private var overlayVisible = false
    
    var body: some View {
        ZStack {
            // Full-Screen Live Camera Preview / Simulator Viewfinder Placeholder
            if cameraService.authorizationStatus == .authorized && cameraService.isCameraAvailable {
                CameraPreviewView(session: cameraService.captureSession)
                    .ignoresSafeArea()
            } else {
                simulatorOrPermissionViewfinder
                    .ignoresSafeArea()
            }
            
            // Visual Guidance Overlay Layer (Target / Move / Warning / Success)
            if let guidance = activeGuidance {
                AssemblyGuidanceOverlayView(guidance: guidance)
            }
            
            // HUD Overlay Layer
            VStack(spacing: 0) {
                // Top Header Overlay: Assembly Step & Cancel Button
                topStepOverlay
                    .padding(.top, 54)
                    .opacity(overlayVisible ? 1 : 0)
                    .offset(y: overlayVisible ? 0 : -20)
                
                Spacer()
                
                // Spatial Inspection Centerpiece Reticle (only if no custom coordinate guidance)
                if activeGuidance == nil || activeGuidance?.hasCoordinates == false {
                    cameraReticleOverlay
                        .opacity(reticleVisible ? 1 : 0)
                        .scaleEffect(reticleVisible ? 1 : 0.9)
                }
                
                Spacer()
                
                // Bottom Action Bar: Analyze Button
                bottomActionBar
                    .padding(.bottom, AppSpacing.xl)
                    .opacity(overlayVisible ? 1 : 0)
                    .offset(y: overlayVisible ? 0 : 20)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            Task {
                if cameraService.authorizationStatus == .notDetermined {
                    await cameraService.requestPermission()
                } else if cameraService.authorizationStatus == .authorized {
                    cameraService.startSession()
                }
            }
            // Staggered entrance animation
            let timing = reduceMotion ? 0.0 : 0.4
            withAnimation(.easeOut(duration: timing).delay(0.1)) {
                overlayVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                reticleVisible = true
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    // MARK: - Top Header Overlay
    
    private var topStepOverlay: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                // Step Progress Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("STEP \(currentStep.stepOrder)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(.ultraThinMaterial))
                .accessibilityLabel("Step \(currentStep.stepOrder)")
                
                Spacer()
                
                // Cancel Button
                Button(action: {
                    cameraService.stopSession()
                    if let onClose = onClose {
                        onClose()
                    } else {
                        router.pop()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Close camera")
            }
            
            // Step Instruction Text Card (if no guidance overlay text)
            if activeGuidance == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentStep.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !currentStep.instruction.isEmpty {
                        Text(currentStep.instruction)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
    
    // MARK: - Center Reticle Crosshairs
    
    private var cameraReticleOverlay: some View {
        ZStack {
            // Target Bounding Box
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Color.assembleBrandPrimary.opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                )
                .frame(width: 260, height: 200)
            
            // Four Corner Alignment Crosshairs
            CameraCornersView()
                .frame(width: 276, height: 216)
                .foregroundColor(Color.assembleBrandPrimary)
            
            // Instruction Hint
            Text("Position component in frame")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(.ultraThinMaterial))
                .offset(y: 124)
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        PrimaryButton(
            title: activeGuidance != nil ? "Scan Again" : "Analyze Step",
            iconName: "viewfinder"
        ) {
            Task {
                let photo = try? await cameraService.capturePhoto()
                cameraService.stopSession()
                if let onAnalyze = onAnalyze {
                    onAnalyze(photo)
                } else {
                    router.navigateToAnalyzing(step: currentStep)
                }
            }
        }
    }
    
    // MARK: - Simulator / Permission Denied Fallback
    
    private var simulatorOrPermissionViewfinder: some View {
        ZStack {
            Color.black
            
            VStack(spacing: AppSpacing.mdLg) {
                Image(systemName: cameraService.authorizationStatus == .denied ? "camera.badge.ellipsis" : "viewfinder")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundColor(Color.assembleBrandPrimary)
                
                VStack(spacing: AppSpacing.xs) {
                    Text(cameraService.authorizationStatus == .denied ? "Camera Access Required" : "Camera Preview")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(cameraService.authorizationStatus == .denied
                         ? "Enable camera access in Settings → Privacy → Camera to observe physical assembly tasks."
                         : "Simulator mode. Tap Analyze Step to preview the verification flow.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
                
                if cameraService.authorizationStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.brandPrimary)
                    .accessibilityHint("Opens iOS Settings to enable camera access")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Assembly Camera View - With Move Guidance") {
    AssemblyCameraView(
        currentStep: AssemblyStep(
            projectId: UUID(),
            stepOrder: 2,
            title: "Attach 100uF Capacitor to C2 Header",
            instruction: "Insert capacitor leads observing polarity."
        ),
        activeGuidance: GuidanceOverlay(
            title: "Wrong position",
            message: "Move component lead one slot to the right (Row 15).",
            sourceRegion: CGRect(x: 100, y: 300, width: 90, height: 60),
            destinationRegion: CGRect(x: 230, y: 300, width: 90, height: 60),
            style: .move
        )
    )
    .environmentObject(AppRouter())
}
