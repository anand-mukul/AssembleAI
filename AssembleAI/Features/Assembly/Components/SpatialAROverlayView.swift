//
//  SpatialAROverlayView.swift
//  AssembleAI
//

import SwiftUI
import CoreGraphics
import simd

/// 3D Spatial AR Guidance Overlay rendering floating perspective-projected volumetric guides.
///
/// Projects 3D spatial beacons, parabolic move arcs, and surface boundaries directly over
/// the camera preview on iOS or within volumetric RealityKit spaces on visionOS.
struct SpatialAROverlayView: View {
    let guidance: GuidanceOverlay
    var workbenchDistanceMeters: Float = 0.35
    
    @State private var pulsePhase: CGFloat = 0.0
    @State private var arcTravelPhase: CGFloat = 0.0
    
    private let guideService = RealityKitSpatialGuideService()
    
    var body: some View {
        GeometryReader { geo in
            let primitives = guideService.generateVolumetricPrimitives(
                from: guidance,
                workbenchDistanceMeters: workbenchDistanceMeters
            )
            
            ZStack {
                ForEach(Array(primitives.enumerated()), id: \.offset) { _, primitive in
                    renderPrimitive(primitive, viewSize: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                arcTravelPhase = 1.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guidance.title). \(guidance.message)")
    }
    
    // MARK: - Primitive Renderers
    
    @ViewBuilder
    private func renderPrimitive(_ primitive: VolumetricGuidancePrimitive, viewSize: CGSize) -> some View {
        switch primitive {
        case .pinBeacon(let position, let radius, let label):
            let screenPoint = projectToScreen(position: position, viewSize: viewSize)
            let diameter = CGFloat(radius * 1200.0)
            
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(Color.assembleBrandPrimary.opacity(0.4 - Double(pulsePhase) * 0.2), lineWidth: 3)
                    .frame(width: diameter * (1.0 + pulsePhase * 0.4), height: diameter * (1.0 + pulsePhase * 0.4))
                
                // Core beacon
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.7))
                    .frame(width: max(14, diameter * 0.4), height: max(14, diameter * 0.4))
                
                // Vertical light beam indicator
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.assembleBrandPrimary.opacity(0.6), Color.clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2, height: 40)
                    .offset(y: -24)
                
                // Floating label
                if !label.isEmpty {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .offset(y: -50)
                }
            }
            .position(screenPoint)
            
        case .moveArc(let from, let to, _, let label):
            let startPoint = projectToScreen(position: from, viewSize: viewSize)
            let endPoint = projectToScreen(position: to, viewSize: viewSize)
            
            ZStack {
                // Parabolic 3D curved trajectory path
                Path { path in
                    path.move(to: startPoint)
                    let midX = (startPoint.x + endPoint.x) / 2.0
                    let midY = min(startPoint.y, endPoint.y) - 50.0 // 3D arc elevation
                    path.addQuadCurve(to: endPoint, control: CGPoint(x: midX, y: midY))
                }
                .strokedPath(StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4]))
                .foregroundColor(AppColors.warning)
                
                // Animated traveling particle
                Circle()
                    .fill(AppColors.warning)
                    .frame(width: 10, height: 10)
                    .position(
                        interpolateQuadratic(
                            p0: startPoint,
                            p1: CGPoint(x: (startPoint.x + endPoint.x) / 2.0, y: min(startPoint.y, endPoint.y) - 50.0),
                            p2: endPoint,
                            t: arcTravelPhase
                        )
                    )
                
                // Floating action banner
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.warning))
                    .position(x: (startPoint.x + endPoint.x) / 2.0, y: min(startPoint.y, endPoint.y) - 65.0)
            }
            
        case .successConfirmation(let position):
            let center = projectToScreen(position: position, viewSize: viewSize)
            ZStack {
                Circle()
                    .stroke(AppColors.success, lineWidth: 4)
                    .frame(width: 80 * (1.0 + pulsePhase * 0.2), height: 80 * (1.0 + pulsePhase * 0.2))
                    .opacity(1.0 - Double(pulsePhase) * 0.5)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(AppColors.success)
            }
            .position(center)
            
        case .planarFrame:
            EmptyView()
        }
    }
    
    // MARK: - Screen Projection Math
    
    private func projectToScreen(position: SIMD3<Float>, viewSize: CGSize) -> CGPoint {
        // Perspective projection: normalize [-1 ... +1] -> [0 ... viewWidth]
        let z = max(0.1, position.z)
        let xScreen = CGFloat((position.x / z) * 600.0) + viewSize.width / 2.0
        let yScreen = CGFloat((position.y / z) * 600.0) + viewSize.height / 2.0
        return CGPoint(
            x: max(20, min(viewSize.width - 20, xScreen)),
            y: max(20, min(viewSize.height - 20, yScreen))
        )
    }
    
    private func interpolateQuadratic(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1.0 - t
        let x = oneMinusT * oneMinusT * p0.x + 2.0 * oneMinusT * t * p1.x + t * t * p2.x
        let y = oneMinusT * oneMinusT * p0.y + 2.0 * oneMinusT * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }
}
