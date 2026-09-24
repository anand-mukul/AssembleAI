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
    var currentIssue: StateIssue? = nil
    
    // Live Tutor Integration Properties
    var liveTutorEnabled: Bool = true
    var liveStatus: LiveTutorStatus = .live
    var currentTutorMessage: TutorResponse? = nil
    var userTranscript: String = ""
    var isListening: Bool = false
    var isPaused: Bool = false
    
    // Jarvis Workspace Calibration
    var workspaceMap: WorkspaceMap? = nil
    var isCalibratingWorkspace: Bool = false
    var onRecalibrateWorkspace: (() -> Void)? = nil
    
    var onStartLiveStream: ((AsyncStream<CVPixelBuffer>) -> Void)? = nil
    var onStopLiveStream: (() -> Void)? = nil
    var onToggleVoice: (() -> Void)? = nil
    var onTogglePause: (() -> Void)? = nil
    var onAnalyze: ((UIImage?) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onSelectStep: ((AssemblyStep) -> Void)? = nil
    var onDismissGuidance: (() -> Void)? = nil
    
    @AppStorage("app_camera_grid") private var showCameraGrid: Bool = true
    @AppStorage("app_reticle_pulsing") private var reticlePulsing: Bool = true
    @AppStorage("app_haptics_enabled") private var hapticsEnabled: Bool = true
    
    @State private var reticleVisible = false
    @State private var overlayVisible = false
    @State private var showStepsSheet = false
    @State private var showWhySheet = false
    @State private var showDimLightPrompt = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var showCalibrationCard = true
    @State private var autoDismissTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top + 6, 56.0)
            let bottomInset = max(proxy.safeAreaInsets.bottom + 8, 28.0)
            
            ZStack {
                // Full-Screen Live Camera Preview / Spatial Hardware Studio Canvas
                if cameraService.authorizationStatus == .authorized && cameraService.isCameraAvailable {
                    CameraPreviewView(session: cameraService.captureSession)
                        .ignoresSafeArea()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Live camera feed")
                } else {
                    simulatorOrPermissionViewfinder
                        .ignoresSafeArea()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Camera unavailable or waiting for permission")
                }
                
                // Alignment Grid Overlay (Configurable via Settings)
                if showCameraGrid {
                    cameraGridOverlay
                }
                
                // Jarvis Holographic Workspace Calibration & Mapping Layer (AR highlight in 3D camera space)
                if isCalibratingWorkspace || (workspaceMap != nil && activeGuidance == nil) {
                    WorkspaceCalibrationView(
                        workspaceMap: workspaceMap,
                        isCalibrating: isCalibratingWorkspace
                    )
                    .transition(.opacity)
                }
                
                // Visual Guidance Overlay Layer (Target / Move / Warning / Success)
                if let guidance = activeGuidance {
                    if guidance.hasCoordinates {
                        SpatialAROverlayView(guidance: guidance)
                    } else {
                        AssemblyGuidanceOverlayView(
                            guidance: guidance,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    onDismissGuidance?()
                                }
                            }
                        )
                    }
                }
                
                // Spatial Inspection Centerpiece Reticle (only if no custom coordinate guidance)
                if activeGuidance == nil || activeGuidance?.hasCoordinates == false {
                    cameraReticleOverlay
                        .opacity(reticleVisible ? 1 : 0)
                        .scaleEffect(reticleVisible ? (reticlePulsing ? pulseScale : 1.0) : 0.9)
                }
                
                // Foreground UI Layout: Apple Vision Pro & iOS 18 HIG
                VStack(spacing: 0) {
                    // Top Header Overlay: Back (Left) + Steps (Right) with zero center occlusion
                    topNavigationBar
                        .padding(.top, topInset)
                        .padding(.horizontal, 16)
                        .opacity(overlayVisible ? 1 : 0)
                        .offset(y: overlayVisible ? 0 : -16)
                    
                    if showDimLightPrompt && !cameraService.isTorchOn {
                        dimLightConsentBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Jarvis Workspace Calibration Banner: Cleanly placed BELOW the top navigation bar!
                    if showCalibrationCard && (isCalibratingWorkspace || (workspaceMap != nil && activeGuidance == nil)) {
                        WorkspaceCalibrationCard(
                            workspaceMap: workspaceMap,
                            isCalibrating: isCalibratingWorkspace,
                            onRecalibrate: {
                                showCalibrationCard = true
                                onRecalibrateWorkspace?()
                            },
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showCalibrationCard = false
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                    
                    Spacer()
                    
                    // Floating Apple Intelligence Thinking Orb
                    if liveTutorEnabled {
                        ThinkingOrbView(status: liveStatus, diameter: 42)
                            .shadow(color: AppColors.glassShadow, radius: 12, x: 0, y: 4)
                            .padding(.bottom, 4)
                            .opacity(overlayVisible ? 1 : 0)
                            .scaleEffect(overlayVisible ? 1 : 0.85)
                        
                        // Camera Optical Zoom Switcher (0.5× wide for furniture/engines, 2× macro for circuits)
                        cameraZoomSelector
                            .padding(.bottom, 8)
                            .opacity(overlayVisible ? 1 : 0)
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, bottomInset)
                        .opacity(overlayVisible ? 1 : 0)
                        .offset(y: overlayVisible ? 0 : 16)
                    } else {
                        bottomActionBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, bottomInset)
                            .opacity(overlayVisible ? 1 : 0)
                            .offset(y: overlayVisible ? 0 : 16)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
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
                issue: currentIssue ?? StateIssue(
                    type: .wrongPosition,
                    title: "Placement Adjustment",
                    explanation: currentTutorMessage?.text ?? "Inspect the physical workpiece alignment according to the step instructions."
                )
            )
        }
        .task {
            if cameraService.authorizationStatus == .notDetermined {
                await cameraService.requestPermission()
            }
            if cameraService.authorizationStatus == .authorized {
                cameraService.startSession()
                if liveTutorEnabled {
                    onStartLiveStream?(cameraService.frameStream)
                }
            }
        }
        .onAppear {
            
            let timing = reduceMotion ? 0.0 : 0.4
            withAnimation(.easeOut(duration: timing).delay(0.1)) {
                overlayVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                reticleVisible = true
            }
            if workspaceMap != nil && !isCalibratingWorkspace {
                scheduleCalibrationCardDismiss()
            }
        }
        .onChange(of: isCalibratingWorkspace) { _, isCalibrating in
            if isCalibrating {
                autoDismissTask?.cancel()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCalibrationCard = true
                }
            } else if workspaceMap != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCalibrationCard = true
                }
                scheduleCalibrationCardDismiss()
            }
        }
        .onDisappear {
            if liveTutorEnabled {
                onStopLiveStream?()
            }
            cameraService.stopSession()
        }
        .onChange(of: activeGuidance) { _, newGuidance in
            guard let g = newGuidance, g.style == .warning else { return }
            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if activeGuidance == g {
                    withAnimation(.easeOut(duration: 0.3)) {
                        onDismissGuidance?()
                    }
                }
            }
        }
        .onChange(of: workspaceMap?.lightingQuality) { _, newLighting in
            if newLighting == .dim && !cameraService.isTorchOn && cameraService.isTorchSupported {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDimLightPrompt = true
                }
            } else if newLighting != .dim {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDimLightPrompt = false
                }
            }
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
            
            // Hardware Torch / Flashlight Button
            if cameraService.isTorchSupported {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    cameraService.toggleTorch()
                }) {
                    ZStack {
                        Circle()
                            .fill(cameraService.isTorchOn ? Color.yellow.opacity(0.3) : Color.black.opacity(0.35))
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .strokeBorder(cameraService.isTorchOn ? Color.yellow.opacity(0.8) : Color.white.opacity(0.20), lineWidth: 0.5)
                        
                        Image(systemName: cameraService.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(cameraService.isTorchOn ? .yellow : .white)
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: cameraService.isTorchOn ? Color.yellow.opacity(0.35) : Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Toggle flashlight")
            }
            
            Spacer()
            
            // Compact Workspace Calibration Pill in top bar when banner is dismissed
            if let map = workspaceMap, !showCalibrationCard {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showCalibrationCard = true
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.aiCyan)
                        Text(map.domain == .electronics ? (map.breadboardVariant == .fullSize ? "830-Pt" : "400-Pt") : map.domain.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 32)
                    .background(
                        ZStack {
                            Capsule().fill(Color.black.opacity(0.35))
                            Capsule().fill(.ultraThinMaterial)
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(AppColors.aiCyan.opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Show workspace calibration details")
                .transition(.scale.combined(with: .opacity))
                
                Spacer()
            }
            
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
    
    // MARK: - Optical Zoom Switcher
    
    private var cameraZoomSelector: some View {
        HStack(spacing: 3) {
            ForEach(cameraService.availableZoomOptions) { option in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        cameraService.setZoomFactor(option.factor)
                    }
                }) {
                    Text(option.label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(abs(cameraService.zoomFactor - option.factor) < 0.05 ? .black : .white)
                        .frame(width: 34, height: 26)
                        .background(
                            Capsule()
                                .fill(abs(cameraService.zoomFactor - option.factor) < 0.05 ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Zoom \(option.label)")
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.40))
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5))
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Dim Light Consent Banner (Apple HIG)
    
    private var dimLightConsentBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "flashlight.on.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.yellow)
            
            Text("Workspace is dim.")
                .font(.caption.weight(.medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cameraService.toggleTorch()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDimLightPrompt = false
                }
            }) {
                Text("Turn On")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.yellow))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDimLightPrompt = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Dismiss flashlight suggestion")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1))
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
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
    
    private func scheduleCalibrationCardDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showCalibrationCard = false
                    }
                }
            }
        }
    }
    
    // MARK: - Camera Viewfinder Backdrop (Simulator / Permission / Standby Mode)
    
    private var simulatorOrPermissionViewfinder: some View {
        ZStack {
            if cameraService.authorizationStatus == .denied || cameraService.authorizationStatus == .restricted {
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
                // Studio Viewfinder Backdrop (Initializing / Simulator Standby)
                ZStack {
                    RadialGradient(
                        colors: [Color(white: 0.10), Color.black],
                        center: .center,
                        startRadius: 60,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                    
                    #if targetEnvironment(simulator)
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Camera Standby (Simulator)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Connect a physical device with a camera for live optical tracking.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    #endif
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
