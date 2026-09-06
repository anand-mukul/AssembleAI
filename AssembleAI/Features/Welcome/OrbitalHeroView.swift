//
//  OrbitalHeroView.swift
//  AssembleAI
//

import SwiftUI

/// Precision orbital animation component featuring floating hardware SF Symbols
/// orbiting a central optical inspection mark with subtle studio illumination.
struct OrbitalHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var appeared = false
    
    private let outerIcons = ["cpu.fill", "memorychip.fill", "camera.viewfinder"]
    private let innerIcons = ["waveform", "checkmark.seal.fill", "bolt.fill"]
    
    var body: some View {
        ZStack {
            // Subtle ambient studio illumination
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.glowPrimary,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(pulseScale)
            
            // Outer orbit ring
            Circle()
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                .frame(width: 240, height: 240)
            
            // Inner orbit ring
            Circle()
                .strokeBorder(AppColors.borderSubtle.opacity(0.6), lineWidth: 0.5)
                .frame(width: 150, height: 150)
            
            // Outer orbit icons (3 icons evenly spaced)
            ForEach(0..<outerIcons.count, id: \.self) { index in
                let angle = (360.0 / Double(outerIcons.count)) * Double(index) + rotationAngle
                orbitalIcon(
                    systemName: outerIcons[index],
                    angle: angle,
                    radius: 120,
                    size: 38,
                    iconSize: 16
                )
            }
            
            // Inner orbit icons (3 icons evenly spaced, counter-rotating)
            ForEach(0..<innerIcons.count, id: \.self) { index in
                let angle = (360.0 / Double(innerIcons.count)) * Double(index) - rotationAngle * 0.75
                orbitalIcon(
                    systemName: innerIcons[index],
                    angle: angle,
                    radius: 75,
                    size: 32,
                    iconSize: 13
                )
            }
            
            // Central AI / Camera Mark
            ZStack {
                Circle()
                    .fill(AppColors.secondaryGroupedBackground)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                    )
                    .shadow(color: AppShadow.subtleColor, radius: 8, x: 0, y: 2)
                
                Image(systemName: "viewfinder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
                
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.assembleBrandPrimary)
            }
            .scaleEffect(pulseScale)
        }
        .frame(height: 270)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(AppAnimation.heroReveal) {
                appeared = true
            }
            
            guard !reduceMotion else { return }
            
            withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.03
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
                .fill(AppColors.secondaryGroupedBackground)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                )
                .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
            
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(AppColors.primaryText)
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
