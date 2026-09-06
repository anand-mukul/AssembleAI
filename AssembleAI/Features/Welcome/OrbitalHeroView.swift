//
//  OrbitalHeroView.swift
//  AssembleAI
//

import SwiftUI

/// Luma-inspired orbital animation component featuring floating hardware SF Symbols
/// orbiting a central AI spark mark on concentric rings with ambient glow.
struct OrbitalHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var appeared = false
    
    private let outerIcons = ["cpu.fill", "memorychip.fill", "camera.viewfinder"]
    private let innerIcons = ["waveform", "checkmark.seal.fill", "bolt.fill"]
    
    var body: some View {
        ZStack {
            // Ambient glow behind orbital system
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.glowPrimary,
                            AppColors.glowSecondary.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(pulseScale)
            
            // Outer orbit ring
            Circle()
                .strokeBorder(AppColors.glassBorderUnified.opacity(0.4), lineWidth: 0.5)
                .frame(width: 260, height: 260)
            
            // Inner orbit ring
            Circle()
                .strokeBorder(AppColors.glassBorderUnified.opacity(0.3), lineWidth: 0.5)
                .frame(width: 160, height: 160)
            
            // Outer orbit icons (3 icons evenly spaced)
            ForEach(0..<outerIcons.count, id: \.self) { index in
                let angle = (360.0 / Double(outerIcons.count)) * Double(index) + rotationAngle
                orbitalIcon(
                    systemName: outerIcons[index],
                    angle: angle,
                    radius: 130,
                    size: 40,
                    iconSize: 17
                )
            }
            
            // Inner orbit icons (3 icons evenly spaced, counter-rotating)
            ForEach(0..<innerIcons.count, id: \.self) { index in
                let angle = (360.0 / Double(innerIcons.count)) * Double(index) - rotationAngle * 0.7
                orbitalIcon(
                    systemName: innerIcons[index],
                    angle: angle,
                    radius: 80,
                    size: 34,
                    iconSize: 14
                )
            }
            
            // Central AI spark mark
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.iconBadgeGradientStart.opacity(0.3),
                                AppColors.iconBadgeGradientEnd.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                
                ZStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 34, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .scaleEffect(pulseScale)
        }
        .frame(height: 300)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85)
        .onAppear {
            withAnimation(AppAnimation.heroReveal) {
                appeared = true
            }
            
            guard !reduceMotion else { return }
            
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        }
        .accessibilityHidden(true)
    }
    
    private func orbitalIcon(systemName: String, angle: Double, radius: CGFloat, size: CGFloat, iconSize: CGFloat) -> some View {
        let radians = angle * .pi / 180
        let x = cos(radians) * Double(radius)
        let y = sin(radians) * Double(radius)
        
        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                )
                .shadow(color: AppShadow.subtleColor, radius: 6, x: 0, y: 2)
            
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .offset(x: CGFloat(x), y: CGFloat(y))
    }
}

#Preview("Orbital Hero View") {
    ZStack {
        GradientAtmosphereBackground(intensity: .hero)
        OrbitalHeroView()
    }
}
