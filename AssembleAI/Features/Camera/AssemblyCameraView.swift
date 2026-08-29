//
//  AssemblyCameraView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation

/// Full-screen camera guidance experience featuring live AVCaptureSession preview, step overlays, reticles, and Analyze triggers.
struct AssemblyCameraView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var cameraService = CameraService()
    
    let currentStep: AssemblyStep
    
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
            
            // HUD Overlay Layer
            VStack {
                // Top Header Overlay: Assembly Step & Cancel Button
                topStepOverlay
                    .padding(.top, AppSpacing.sm)
                
                Spacer()
                
                // Spatial Inspection Centerpiece Reticle
                cameraReticleOverlay
                
                Spacer()
                
                // Bottom Action Bar: Analyze Button
                bottomActionBar
                    .padding(.bottom, AppSpacing.lg)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                if cameraService.authorizationStatus == .notDetermined {
                    await cameraService.requestPermission()
                } else if cameraService.authorizationStatus == .authorized {
                    cameraService.startSession()
                }
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    // MARK: - Top Header Overlay
    
    private var topStepOverlay: some View {
        VStack(spacing: AppSpacing.xs) {
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
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                
                Spacer()
                
                // Cancel Button
                Button(action: {
                    cameraService.stopSession()
                    router.pop()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.85))
                }
                .accessibilityLabel("Cancel camera inspection")
            }
            
            // Step Instruction Text Card
            VStack(alignment: .leading, spacing: 4) {
                Text(currentStep.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if !currentStep.instruction.isEmpty {
                    Text(currentStep.instruction)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
        }
    }
    
    // MARK: - Center Reticle Crosshairs
    
    private var cameraReticleOverlay: some View {
        ZStack {
            // Target Bounding Box
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Color.assembleBrandPrimary,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .frame(width: 260, height: 200)
            
            // Four Corner Alignment Crosshairs
            CameraCornersView()
                .frame(width: 276, height: 216)
                .foregroundColor(Color.assembleBrandPrimary)
            
            // Instruction Hint
            Text("Frame target component within reticle")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .offset(y: 120)
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: AppSpacing.sm) {
            PrimaryButton(
                title: "Analyze Step",
                iconName: "sparkles.viewfinder"
            ) {
                cameraService.stopSession()
                router.navigateToAnalyzing(step: currentStep)
            }
        }
    }
    
    // MARK: - Simulator / Fallback Viewfinder
    
    private var simulatorOrPermissionViewfinder: some View {
        ZStack {
            Color.black
            
            VStack(spacing: AppSpacing.md) {
                Image(systemName: cameraService.authorizationStatus == .denied ? "camera.metering.unknown" : "viewfinder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(Color.assembleBrandPrimary)
                
                Text(cameraService.authorizationStatus == .denied ? "Camera Access Required" : "Assembly Camera Viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(cameraService.authorizationStatus == .denied ? "Enable camera permissions in Settings to observe physical assembly tasks." : "Simulated Camera Environment. Tap 'Analyze Step' to run visual state verification.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                if cameraService.authorizationStatus == .denied {
                    Button("Grant Permission") {
                        Task {
                            await cameraService.requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.brandPrimary)
                }
            }
        }
    }
}

#Preview("Assembly Camera View") {
    AssemblyCameraView(
        currentStep: AssemblyStep(
            projectId: UUID(),
            stepOrder: 1,
            title: "Attach 10K Resistor to R1 Pin Header",
            instruction: "Insert resistor leads into R1 slots and verify orientation."
        )
    )
    .environmentObject(AppRouter())
}
