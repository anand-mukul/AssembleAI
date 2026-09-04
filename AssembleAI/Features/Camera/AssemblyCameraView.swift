//
//  AssemblyCameraView.swift
//  AssembleAI
//

import SwiftUI
import AVFoundation
import CoreVideo

/// Flagship full-screen camera guidance experience designed to Apple Human Interface Guidelines:
/// - Top Bar: Circular glass back button (leading), Live Apple Intelligence status badge (center), Steps capsule pill button (trailing).
/// - Center: Unobstructed camera feed with spatial AR reticles and zero colliding elements.
/// - Lower Center: Floating Apple Intelligence Thinking Orb (52pt) with ambient glowing aura.
/// - Bottom: Single unified Apple Vision Pro / iOS 18 Dynamic Island Glass HUD.
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
    
    @AppStorage("app_camera_grid") private var showCameraGrid: Bool = true
    @AppStorage("app_reticle_pulsing") private var reticlePulsing: Bool = true
    @AppStorage("app_haptics_enabled") private var hapticsEnabled: Bool = true
    
    @State private var reticleVisible = false
    @State private var overlayVisible = false
    @State private var showStepsSheet = false
    @State private var showWhySheet = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Full-Screen Live Camera Preview / Spatial Hardware Studio Canvas
            if cameraService.authorizationStatus == .authorized && cameraService.isCameraAvailable {
                CameraPreviewView(session: cameraService.captureSession)
                    .ignoresSafeArea()
            } else {
                simulatorOrPermissionViewfinder
                    .ignoresSafeArea()
            }
            
            // Alignment Grid Overlay (Configurable via Settings)
            if showCameraGrid {
                cameraGridOverlay
            }
            
            // Visual Guidance Overlay Layer (Target / Move / Warning / Success)
            if let guidance = activeGuidance {
                SpatialAROverlayView(guidance: guidance)
                AssemblyGuidanceOverlayView(guidance: guidance)
            }
            
            // Spatial Inspection Centerpiece Reticle (only if no custom coordinate guidance)
            if activeGuidance == nil || activeGuidance?.hasCoordinates == false {
                cameraReticleOverlay
                    .opacity(reticleVisible ? 1 : 0)
                    .scaleEffect(reticleVisible ? (reticlePulsing ? pulseScale : 1.0) : 0.9)
            }
            
            // Foreground UI Layout: Apple Vision Pro & iOS 18 HIG
            VStack(spacing: 0) {
                // Top Header Overlay: Back (Left) + Status Pill (Center) + Steps (Right)
                topNavigationBar
                    .safeAreaPadding(.top)
                    .opacity(overlayVisible ? 1 : 0)
                    .offset(y: overlayVisible ? 0 : -20)
                
                Spacer()
                
                // Floating Apple Intelligence Thinking Orb
                if liveTutorEnabled {
                    ThinkingOrbView(status: liveStatus, diameter: 52)
                        .shadow(color: AppColors.glassShadow, radius: 16, x: 0, y: 6)
                        .padding(.bottom, 12)
                        .opacity(overlayVisible ? 1 : 0)
                        .scaleEffect(overlayVisible ? 1 : 0.85)
                }
                
                // Bottom Area: Unified Dynamic Island Glass HUD
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
            .padding(.horizontal, 16)
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
    
    // MARK: - Top Navigation Bar
    
    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            // Circular Frosted Glass Back Button
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
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Back")
            
            Spacer()
            
            // Center Apple Intelligence Live Status Indicator
            if liveTutorEnabled {
                HStack(spacing: 6) {
                    ThinkingOrbView(status: liveStatus, diameter: 14)
                    
                    Text(liveStatus.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        Capsule().fill(Color.black.opacity(0.35))
                        Capsule().fill(.ultraThinMaterial)
                    }
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tutor Status: \(liveStatus.rawValue)")
            }
            
            Spacer()
            
            // Steps Capsule Glass Pill Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStepsSheet = true
            }) {
                HStack(spacing: 7) {
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
                .padding(.horizontal, 12)
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
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Steps overview")
        }
    }
    
    // MARK: - Spatial AR Center Reticle
    
    private var cameraReticleOverlay: some View {
        ZStack {
            // Elegant hairline corner crosshairs
            CameraCornersView()
                .frame(width: 260, height: 200)
                .foregroundColor(Color.white.opacity(0.65))
            
            // Subtle optical center guide
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .ultraLight))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Viewfinder Alignment Grid Overlay
    
    private var cameraGridOverlay: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
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
    
    // MARK: - Spatial Hardware Studio Canvas (Simulator / Standby Mode)
    
    private var simulatorOrPermissionViewfinder: some View {
        ZStack {
            if cameraService.authorizationStatus == .denied {
                // Camera Permission Required View
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: AppSpacing.mdLg) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundColor(Color.assembleBrandPrimary)
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("Camera Access Required")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Enable camera access in Settings → Privacy → Camera to observe physical hardware assembly tasks.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.xl)
                        }
                        
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
            } else {
                // Spatial Studio Inspection Backdrop
                ZStack {
                    // Deep Obsidian Studio Gradient
                    RadialGradient(
                        colors: [Color(white: 0.12), Color.black],
                        center: .center,
                        startRadius: 60,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                    
                    // Hardware Workbench Schematic Simulation
                    VStack(spacing: 16) {
                        Spacer()
                        
                        // Holographic Circuit Alignment Canvas
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 250, height: 180)
                            
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                .frame(width: 250, height: 180)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.assembleBrandPrimary.opacity(0.8))
                                        .frame(width: 6, height: 6)
                                    Text("CIRCUIT WORKSPACE")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("REV 2.4")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                
                                // Simulated Breadboard Grid Lines
                                VStack(spacing: 6) {
                                    ForEach(0..<4) { _ in
                                        HStack(spacing: 8) {
                                            ForEach(0..<10) { _ in
                                                Circle()
                                                    .fill(Color.white.opacity(0.20))
                                                    .frame(width: 3, height: 3)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                // Status indicator
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                    Text("Simulated Optical Stream")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(Color.assembleBrandPrimary.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .frame(width: 250, height: 180)
                        }
                        
                        Spacer()
                    }
                }
                .accessibilityHidden(true)
            }
        }
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
