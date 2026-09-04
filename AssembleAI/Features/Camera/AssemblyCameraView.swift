//
//  AssemblyCameraView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation
import CoreVideo

/// Flagship full-screen camera guidance experience designed to Apple Human Interface Guidelines:
/// - Top Bar: Circular glass back button (leading) + "(steps)" capsule pill button (trailing).
/// - Center: Unobstructed camera feed with spatial AR reticles.
/// - Lower Center: Floating Apple Intelligence Thinking Orb (56pt) with ambient glowing aura.
/// - Bottom: Dual glass cards (Card 1: Step Guide, Card 2: Live Instruction).
struct AssemblyCameraView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var cameraService = CameraService()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let currentStep: AssemblyStep
    var allSteps: [AssemblyStep] = []
    var activeGuidance: GuidanceOverlay? = nil
    
    // Live Tutor Integration Properties
    var liveTutorEnabled: Bool = true
    var liveStatus: LiveTutorStatus = .live
    var currentTutorMessage: TutorResponse? = nil
    var userTranscript: String = ""
    var isListening: Bool = false
    var isPaused: Bool = false
    
    var onStartLiveStream: ((AsyncStream<CVPixelBuffer>) -> Void)? = nil
    var onStopLiveStream: (() -> Void)? = nil
    var onToggleVoice: (() -> Void)? = nil
    var onTogglePause: (() -> Void)? = nil
    var onAnalyze: ((UIImage?) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onSelectStep: ((AssemblyStep) -> Void)? = nil
    
    @State private var reticleVisible = false
    @State private var overlayVisible = false
    @State private var showStepsSheet = false
    @State private var showWhySheet = false
    
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
            
            // Spatial Inspection Centerpiece Reticle (only if no custom coordinate guidance)
            if activeGuidance == nil || activeGuidance?.hasCoordinates == false {
                cameraReticleOverlay
                    .opacity(reticleVisible ? 1 : 0)
                    .scaleEffect(reticleVisible ? 1 : 0.9)
            }
            
            // Foreground UI Layout matching the Wireframe
            VStack(spacing: 0) {
                // Top Header Overlay: Circular Back (Left) + Capsule Steps Pill (Right)
                topNavigationBar
                    .safeAreaPadding(.top)
                    .opacity(overlayVisible ? 1 : 0)
                    .offset(y: overlayVisible ? 0 : -20)
                
                Spacer()
                
                // Floating Apple Intelligence Thinking Orb (As in Wireframe)
                if liveTutorEnabled {
                    ThinkingOrbView(status: liveStatus, diameter: 56)
                        .shadow(color: AppColors.glassShadow, radius: 14, x: 0, y: 8)
                        .padding(.bottom, AppSpacing.sm)
                        .opacity(overlayVisible ? 1 : 0)
                        .scaleEffect(overlayVisible ? 1 : 0.8)
                }
                
                // Bottom Area: Dual Glass Cards (Step Guide + Live Instruction)
                if liveTutorEnabled {
                    LiveTutorHUDView(
                        status: liveStatus,
                        currentStep: currentStep,
                        currentMessage: currentTutorMessage,
                        userTranscript: userTranscript,
                        isListening: isListening,
                        isPaused: isPaused,
                        onToggleVoice: {
                            onToggleVoice?()
                        },
                        onTogglePause: {
                            onTogglePause?()
                        },
                        onManualFallback: {
                            triggerManualSnapshot()
                        },
                        onExplainWhy: {
                            showWhySheet = true
                        }
                    )
                    .safeAreaPadding(.bottom)
                    .padding(.bottom, AppSpacing.xs)
                    .opacity(overlayVisible ? 1 : 0)
                    .offset(y: overlayVisible ? 0 : 20)
                } else {
                    bottomActionBar
                        .safeAreaPadding(.bottom)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(overlayVisible ? 1 : 0)
                        .offset(y: overlayVisible ? 0 : 20)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .sheet(isPresented: $showStepsSheet) {
            StepsOverviewSheet(
                currentStep: currentStep,
                allSteps: allSteps.isEmpty ? [currentStep] : allSteps,
                onSelectStep: onSelectStep
            )
        }
        .sheet(isPresented: $showWhySheet) {
            WhyExplanationSheet(
                step: currentStep,
                issue: StateIssue(
                    type: .wrongPosition,
                    title: "Placement Adjustment",
                    explanation: currentTutorMessage?.text ?? "Inspect the indicated pin routing on the breadboard."
                )
            )
        }
        .onAppear {
            Task {
                if cameraService.authorizationStatus == .notDetermined {
                    await cameraService.requestPermission()
                } else if cameraService.authorizationStatus == .authorized {
                    cameraService.startSession()
                    if liveTutorEnabled {
                        onStartLiveStream?(cameraService.frameStream)
                    }
                }
            }
            
            let timing = reduceMotion ? 0.0 : 0.4
            withAnimation(.easeOut(duration: timing).delay(0.1)) {
                overlayVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                reticleVisible = true
            }
        }
        .onDisappear {
            if liveTutorEnabled {
                onStopLiveStream?()
            }
            cameraService.stopSession()
        }
    }
    
    // MARK: - Top Navigation Bar (Wireframe Layout)
    
    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            // Circular Frosted Glass Back Button (Wireframe Left)
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if liveTutorEnabled {
                    onStopLiveStream?()
                }
                cameraService.stopSession()
                if let onClose = onClose {
                    onClose()
                } else {
                    router.pop()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                .shadow(color: AppColors.glassShadow, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Back")
            
            Spacer()
            
            // Steps Capsule Glass Pill Button (Wireframe Right)
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStepsSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12, weight: .bold))
                    Text("Steps")
                        .font(.subheadline.weight(.semibold))
                    
                    Text("\(currentStep.stepOrder)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.assembleBrandPrimary))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    ZStack {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(.ultraThinMaterial)
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                )
                .shadow(color: AppColors.glassShadow, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Steps overview")
        }
    }
    
    // MARK: - Center Reticle Crosshairs
    
    private var cameraReticleOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(
                    Color.assembleBrandPrimary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                )
                .frame(width: 260, height: 200)
            
            CameraCornersView()
                .frame(width: 276, height: 216)
                .foregroundColor(Color.assembleBrandPrimary.opacity(0.75))
            
            Text(liveTutorEnabled ? "Live observation active" : "Position component in frame")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    ZStack {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(.ultraThinMaterial)
                    }
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .offset(y: 124)
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Legacy Bottom Action Bar
    
    private var bottomActionBar: some View {
        PrimaryButton(
            title: activeGuidance != nil ? "Scan Again" : "Analyze Step",
            iconName: "viewfinder"
        ) {
            triggerManualSnapshot()
        }
    }
    
    private func triggerManualSnapshot() {
        Task {
            let photo = try? await cameraService.capturePhoto()
            if liveTutorEnabled {
                onStopLiveStream?()
            }
            cameraService.stopSession()
            if let onAnalyze = onAnalyze {
                onAnalyze(photo)
            } else {
                router.navigateToAnalyzing(step: currentStep)
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
                         : (liveTutorEnabled ? "Simulator mode. Live Tutor is observing mock frame stream." : "Simulator mode. Tap Analyze Step to preview."))
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

#Preview("Assembly Camera View - Live Tutor Mode") {
    AssemblyCameraView(
        currentStep: AssemblyStep(
            projectId: UUID(),
            stepOrder: 2,
            title: "Attach 100uF Capacitor to C2 Header",
            instruction: "Insert capacitor leads observing polarity."
        ),
        liveTutorEnabled: true,
        liveStatus: .live,
        currentTutorMessage: TutorResponse(text: "Move component lead one slot to the right.", priority: .high)
    )
    .environmentObject(AppRouter())
}
