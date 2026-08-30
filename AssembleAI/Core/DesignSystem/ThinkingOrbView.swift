//
//  ThinkingOrbView.swift
//  AssembleAI
//
//  Native SwiftUI implementation of Jakub Antalik's Thinking Orbs
//  for AI agent states (Live, Listening, Speaking, Verifying, Paused).
//

import SwiftUI

// MARK: - Thinking Orb State

/// Semantic operational state governing the orb particle math, harmonics, frequency, and palette.
enum ThinkingOrbState: String, Sendable, Equatable {
    case live        // Breathing & harmonic rotation (Idle / Ambient)
    case listening   // Concentric wave ripple & acoustic contraction
    case speaking    // Orbital harmonic wave & voice dispersion
    case verifying   // High-speed vortex & particle solving
    case paused      // Dimmed resting orbit
}

// MARK: - Thinking Orb Component

/// High-performance, Metal-accelerated SwiftUI Canvas rendering Jakub Antalik-inspired dotted thinking orbs.
///
/// Supports automatic dark/light appearance adaptation, ProMotion 120 FPS scaling, and Reduce Motion accessibility.
struct ThinkingOrbView: View {
    let state: ThinkingOrbState
    var diameter: CGFloat = 24
    var customColor: Color? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        state: ThinkingOrbState = .live,
        diameter: CGFloat = 24,
        customColor: Color? = nil
    ) {
        self.state = state
        self.diameter = diameter
        self.customColor = customColor
    }
    
    /// Convenience initializer mapping from LiveTutorStatus
    init(
        status: LiveTutorStatus,
        diameter: CGFloat = 24,
        customColor: Color? = nil
    ) {
        let orbState: ThinkingOrbState
        switch status {
        case .live: orbState = .live
        case .listening: orbState = .listening
        case .speaking: orbState = .speaking
        case .verifying: orbState = .verifying
        case .paused: orbState = .paused
        }
        self.init(state: orbState, diameter: diameter, customColor: customColor)
    }
    
    var body: some View {
        Group {
            if reduceMotion || state == .paused {
                staticReducedMotionOrb
            } else {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        drawOrb(context: context, size: size, time: time)
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AssembleAI status: \(state.rawValue)")
    }
    
    // MARK: - Canvas Rendering Engine
    
    private func drawOrb(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.42
        let dotColor = customColor ?? primaryColor
        
        switch state {
        case .live:
            drawBreathingOrb(context: context, center: center, radius: radius, time: time, color: dotColor)
        case .listening:
            drawListeningOrb(context: context, center: center, radius: radius, time: time, color: dotColor)
        case .speaking:
            drawSpeakingOrb(context: context, center: center, radius: radius, time: time, color: dotColor)
        case .verifying:
            drawVerifyingOrb(context: context, center: center, radius: radius, time: time, color: dotColor)
        case .paused:
            drawPausedOrb(context: context, center: center, radius: radius, color: dotColor)
        }
    }
    
    // MARK: - 1. Live State: Breathing Harmonic Ring
    
    private func drawBreathingOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, color: Color) {
        let dotCount = 18
        let speed = 1.4
        let breath = sin(time * 2.2) * 0.12 + 0.88
        
        for i in 0..<dotCount {
            let angle = (Double(i) / Double(dotCount)) * 2 * .pi + (time * speed)
            let wave = sin(time * 3.0 + Double(i) * 0.6) * 0.15
            let r = radius * CGFloat(breath + wave)
            
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            let dotSize = max(1.2, CGFloat(1.8 + wave * 2.0) * (diameter / 24))
            
            let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.75 + wave * 0.25)))
        }
        
        // Ambient Central Core Dot
        let coreSize = CGFloat(2.4) * (diameter / 24)
        let coreRect = CGRect(x: center.x - coreSize / 2, y: center.y - coreSize / 2, width: coreSize, height: coreSize)
        context.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(0.9)))
    }
    
    // MARK: - 2. Listening State: Concentric Acoustic Wave
    
    private func drawListeningOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, color: Color) {
        let rings = 2
        let dotsPerRing = 14
        let pulse = abs(sin(time * 4.5))
        
        for ring in 0..<rings {
            let ringScale = ring == 0 ? (0.55 + pulse * 0.25) : (0.85 + pulse * 0.15)
            let currentRadius = radius * CGFloat(ringScale)
            let speed = ring == 0 ? 2.5 : -1.8
            
            for i in 0..<dotsPerRing {
                let angle = (Double(i) / Double(dotsPerRing)) * 2 * .pi + (time * speed)
                let x = center.x + currentRadius * cos(angle)
                let y = center.y + currentRadius * sin(angle)
                let dotSize = max(1.0, CGFloat(1.6 + pulse * 1.0) * (diameter / 24))
                
                let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                let alpha = ring == 0 ? 0.9 : 0.6
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
    }
    
    // MARK: - 3. Speaking State: Dispersing Vocal Harmonics
    
    private func drawSpeakingOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, color: Color) {
        let dotCount = 20
        let harmonic = sin(time * 5.0)
        
        for i in 0..<dotCount {
            let baseAngle = (Double(i) / Double(dotCount)) * 2 * .pi
            let wobble = sin(baseAngle * 3.0 + time * 6.0) * 0.22
            let r = radius * CGFloat(0.85 + wobble)
            let angle = baseAngle + (time * 2.0)
            
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            let dotSize = max(1.2, CGFloat(2.0 + abs(harmonic) * 1.2) * (diameter / 24))
            
            let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
        }
    }
    
    // MARK: - 4. Verifying State: High-Speed Particle Vortex
    
    private func drawVerifyingOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, color: Color) {
        let arms = 3
        let dotsPerArm = 6
        let speed = 7.0
        
        for arm in 0..<arms {
            let armOffset = (Double(arm) / Double(arms)) * 2 * .pi
            for j in 0..<dotsPerArm {
                let fraction = Double(j + 1) / Double(dotsPerArm)
                let r = radius * CGFloat(fraction)
                let angle = armOffset + (fraction * 1.8) + (time * speed)
                
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)
                let dotSize = max(1.0, CGFloat(1.2 + fraction * 1.6) * (diameter / 24))
                
                let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.3 + fraction * 0.7)))
            }
        }
    }
    
    // MARK: - 5. Paused State: Resting Minimalist Ring
    
    private func drawPausedOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let dotCount = 12
        for i in 0..<dotCount {
            let angle = (Double(i) / Double(dotCount)) * 2 * .pi
            let r = radius * 0.85
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            let dotSize = CGFloat(1.5) * (diameter / 24)
            
            let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.4)))
        }
    }
    
    // MARK: - Static Fallback for Reduce Motion
    
    private var staticReducedMotionOrb: some View {
        ZStack {
            Circle()
                .strokeBorder(primaryColor.opacity(0.35), lineWidth: 1.5)
                .frame(width: diameter * 0.85, height: diameter * 0.85)
            
            Circle()
                .fill(primaryColor)
                .frame(width: diameter * 0.35, height: diameter * 0.35)
        }
    }
    
    // MARK: - Color Palette
    
    private var primaryColor: Color {
        switch state {
        case .live: return AppColors.statusLive
        case .listening: return AppColors.statusListening
        case .speaking: return AppColors.statusSpeaking
        case .verifying: return AppColors.statusVerifying
        case .paused: return AppColors.statusPaused
        }
    }
}


#Preview("Thinking Orbs") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            VStack {
                ThinkingOrbView(state: .live, diameter: 44)
                Text("Live").font(.caption).foregroundColor(.white)
            }
            VStack {
                ThinkingOrbView(state: .listening, diameter: 44)
                Text("Listening").font(.caption).foregroundColor(.white)
            }
            VStack {
                ThinkingOrbView(state: .speaking, diameter: 44)
                Text("Speaking").font(.caption).foregroundColor(.white)
            }
            VStack {
                ThinkingOrbView(state: .verifying, diameter: 44)
                Text("Verifying").font(.caption).foregroundColor(.white)
            }
            VStack {
                ThinkingOrbView(state: .paused, diameter: 44)
                Text("Paused").font(.caption).foregroundColor(.white)
            }
        }
    }
    .padding()
    .background(Color.black.ignoresSafeArea())
}
