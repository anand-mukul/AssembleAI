//
//  WorkspaceCalibrationView.swift
//  AssembleAI
//

import SwiftUI

/// Jarvis-style futuristic holographic workspace scanning overlay.
/// Sweeps across the camera feed to calibrate breadboard grid, detect size, and map existing components in 3D camera space.
struct WorkspaceCalibrationView: View {
    let workspaceMap: WorkspaceMap?
    let isCalibrating: Bool
    
    @State private var scanlineOffset: CGFloat = -1.0
    @State private var radarRotation: Double = 0.0
    @State private var gridOpacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // 1. Holographic Scanning Grid Overlay
            if isCalibrating {
                scanningRadarOverlay
                scanlineSweepView
            }
            
            // 2. Calibrated Workspace Bounds Box
            if let map = workspaceMap {
                if map.breadboardDetected, let calib = map.breadboardCalibration {
                    detectedBreadboardHighlight(calib: calib)
                } else if map.domain != .electronics {
                    detectedWorkbenchHighlight(area: map.estimatedWorkingArea)
                }
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    scanlineOffset = 1.0
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    radarRotation = 360.0
                }
            }
            withAnimation(.easeIn(duration: 0.5)) {
                gridOpacity = 1.0
            }
        }
    }
    
    // MARK: - Scanning Radar Sweep
    
    private var scanningRadarOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Radial pulse
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.assembleBrandPrimary.opacity(0.0),
                                Color.assembleBrandPrimary.opacity(0.4),
                                AppColors.aiCyan.opacity(0.8)
                            ]),
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: min(geo.size.width, geo.size.height) * 0.75, height: min(geo.size.width, geo.size.height) * 0.75)
                    .rotationEffect(.degrees(radarRotation))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Outer target crosshairs
                Path { path in
                    let cx = geo.size.width / 2
                    let cy = geo.size.height / 2
                    let len: CGFloat = 30
                    
                    // Center reticle lines
                    path.move(to: CGPoint(x: cx - len, y: cy))
                    path.addLine(to: CGPoint(x: cx + len, y: cy))
                    path.move(to: CGPoint(x: cx, y: cy - len))
                    path.addLine(to: CGPoint(x: cx, y: cy + len))
                }
                .stroke(AppColors.aiCyan.opacity(0.6), lineWidth: 1.0)
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Scanline Sweep
    
    private var scanlineSweepView: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            AppColors.aiCyan.opacity(0.15),
                            AppColors.aiCyan.opacity(0.40),
                            Color.white.opacity(0.70),
                            AppColors.aiCyan.opacity(0.40),
                            AppColors.aiCyan.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 35)
                .offset(y: (scanlineOffset + 1.0) / 2.0 * geo.size.height)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Detected Breadboard Spatial Highlight
    
    private func detectedBreadboardHighlight(calib: BreadboardCalibration) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                path.move(to: CGPoint(x: calib.topLeft.x * w, y: calib.topLeft.y * h))
                path.addLine(to: CGPoint(x: calib.topRight.x * w, y: calib.topRight.y * h))
                path.addLine(to: CGPoint(x: calib.bottomRight.x * w, y: calib.bottomRight.y * h))
                path.addLine(to: CGPoint(x: calib.bottomLeft.x * w, y: calib.bottomLeft.y * h))
                path.closeSubpath()
            }
            .stroke(
                AppColors.aiCyan,
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round, dash: [6, 4])
            )
            .shadow(color: AppColors.aiCyan.opacity(0.6), radius: 8)
            .overlay(
                // Corner pins
                ZStack {
                    cornerReticle(at: CGPoint(x: calib.topLeft.x * w, y: calib.topLeft.y * h))
                    cornerReticle(at: CGPoint(x: calib.topRight.x * w, y: calib.topRight.y * h))
                    cornerReticle(at: CGPoint(x: calib.bottomRight.x * w, y: calib.bottomRight.y * h))
                    cornerReticle(at: CGPoint(x: calib.bottomLeft.x * w, y: calib.bottomLeft.y * h))
                }
            )
        }
        .allowsHitTesting(false)
    }
    
    private func detectedWorkbenchHighlight(area: CGRect) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rect = CGRect(
                x: area.origin.x * w,
                y: area.origin.y * h,
                width: area.size.width * w,
                height: area.size.height * h
            )
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    AppColors.aiCyan,
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: AppColors.aiCyan.opacity(0.4), radius: 6)
        }
        .allowsHitTesting(false)
    }
    
    private func cornerReticle(at point: CGPoint) -> some View {
        Circle()
            .fill(AppColors.aiCyan)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .shadow(color: AppColors.aiCyan, radius: 4)
            .position(point)
    }
    
}

// MARK: - Jarvis Workspace Calibration Card

/// Floating Glass Island displaying Jarvis workspace calibration telemetry and status.
/// Intentionally decoupled from the AR overlay and placed below the top navigation bar to prevent UI overlapping.
struct WorkspaceCalibrationCard: View {
    let workspaceMap: WorkspaceMap?
    let isCalibrating: Bool
    var onRecalibrate: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(spacing: 8) {
                ThinkingOrbView(status: isCalibrating ? .verifying : .live, diameter: 12)
                
                Text(isCalibrating ? "JARVIS WORKBENCH SCANNING" : ((workspaceMap?.breadboardDetected == true || workspaceMap?.domain != .electronics) ? "WORKSPACE CALIBRATED" : "ALIGN WORKPIECE"))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.aiCyan)
                    .tracking(1.2)
                
                Spacer()
                
                HStack(spacing: 6) {
                    if let onRecalibrate = onRecalibrate, !isCalibrating {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onRecalibrate()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("Recalibrate workspace")
                    }
                    
                    if let onDismiss = onDismiss {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("Dismiss calibration card")
                    }
                }
            }
            
            // Subtitle status
            if isCalibrating {
                Text("Analyzing surface geometry, components & lighting...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.95))
            } else if let map = workspaceMap {
                Text(map.summaryAnnouncement)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Telemetry Pills
                HStack(spacing: 6) {
                    if map.domain == .electronics {
                        if map.breadboardDetected {
                            telemetryPill(
                                icon: "square.grid.3x3.fill",
                                title: map.breadboardVariant == .fullSize ? "830-Point Full" : "400-Point Half",
                                color: AppColors.badgeBlue
                            )
                        } else {
                            telemetryPill(
                                icon: "viewfinder",
                                title: "Searching...",
                                color: AppColors.badgeOrange
                            )
                        }
                    } else {
                        telemetryPill(
                            icon: map.domain.iconName,
                            title: map.domain.displayName,
                            color: AppColors.badgeBlue
                        )
                    }
                    
                    telemetryPill(
                        icon: "sun.max.fill",
                        title: map.lightingQuality.rawValue,
                        color: map.lightingQuality == .optimal ? AppColors.badgeGreen : AppColors.badgeOrange
                    )
                    
                    telemetryPill(
                        icon: "shippingbox.fill",
                        title: "\(map.existingComponents.count) on bench",
                        color: Color.assembleBrandPrimary
                    )
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppColors.aiCyan.opacity(0.5), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
    }
    
    private func telemetryPill(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.25)))
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 0.5))
        .foregroundColor(.white)
    }
}
