//
//  LiveTutorHUDView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

// MARK: - Live Tutor Status

/// Visual operational status of the live tutor HUD.
enum LiveTutorStatus: String, Sendable, Equatable {
    case live = "LIVE"
    case paused = "PAUSED"
    case speaking = "SPEAKING"
    case listening = "LISTENING"
    case verifying = "CHECKING"
}

// MARK: - Live Tutor Configuration

/// Feature flag configuration governing Live Tutor Mode vs Legacy Manual Analysis Mode.
struct LiveTutorConfiguration: Sendable, Equatable {
    var isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    static let `default` = LiveTutorConfiguration(isEnabled: true)
}

// MARK: - Live Tutor HUD View

/// Floating, compact Live Tutor HUD overlay presenting real-time conversational guidance, voice controls, and Jakub Antalik thinking orbs.
struct LiveTutorHUDView: View {
    let status: LiveTutorStatus
    let currentStep: AssemblyStep
    let currentMessage: TutorResponse?
    let userTranscript: String
    let isListening: Bool
    let isPaused: Bool
    
    var onToggleVoice: () -> Void
    var onTogglePause: () -> Void
    var onManualFallback: (() -> Void)? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Floating Assistant Glass Card
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Card Header: Status Badge with Thinking Orb & Pause/Resume Control
                HStack {
                    statusBadge
                    
                    Spacer()
                    
                    // Pause / Resume Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onTogglePause()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isPaused ? "Resume" : "Pause")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(isPaused ? "Resume Live Tutor" : "Pause Live Tutor")
                }
                
                // Conversational Dialogue Body
                if isListening {
                    userTranscriptView
                } else if let message = currentMessage {
                    assistantMessageView(message)
                } else {
                    quietObservingView
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                cardBorderColor.opacity(0.6),
                                cardBorderColor.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            
            // Bottom Controls Bar: Tap-to-Talk Button & Secondary Actions
            HStack(spacing: AppSpacing.md) {
                // Tap-to-Talk Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onToggleVoice()
                }) {
                    HStack(spacing: 8) {
                        if isListening {
                            ThinkingOrbView(status: .listening, diameter: 18, customColor: .white)
                            Text("Listening...")
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("Talk to AssembleAI")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(isListening ? AppColors.error : Color.assembleBrandPrimary)
                    )
                    .shadow(color: (isListening ? AppColors.error : Color.assembleBrandPrimary).opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isListening ? "Stop listening" : "Talk to AssembleAI")
                
                // Manual Capture Fallback (if user desires explicit snapshot)
                if let onManualFallback = onManualFallback {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onManualFallback()
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Manual snapshot analysis")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            ThinkingOrbView(status: status, diameter: 16)
            
            Text(status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("AssembleAI")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.ultraThinMaterial))
    }
    
    private func assistantMessageView(_ message: TutorResponse) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if status == .speaking {
                VoiceEqualizerView()
                    .padding(.top, 3)
            }
            
            Text(message.text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
        }
        .padding(.top, 2)
    }
    
    private var userTranscriptView: some View {
        HStack(spacing: 8) {
            ThinkingOrbView(status: .listening, diameter: 14)
            
            Text(userTranscript.isEmpty ? "Listening to your question..." : userTranscript)
                .font(.subheadline)
                .italic()
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
        }
        .padding(.top, 2)
    }
    
    private var quietObservingView: some View {
        HStack(spacing: 6) {
            Image(systemName: isPaused ? "pause.circle" : "eye")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Text(isPaused ? "Live guidance is paused." : "Watching assembly. Start when you're ready.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.top, 2)
    }
    
    // MARK: - Color Properties
    
    private var cardBorderColor: Color {
        switch status {
        case .live: return AppColors.success
        case .paused: return Color.gray
        case .speaking: return Color.purple
        case .listening: return AppColors.warning
        case .verifying: return Color.assembleBrandPrimary
        }
    }
}

// MARK: - Voice Equalizer Bar Animation

/// Animated 3-bar audio equalizer indicating active spoken dialogue.
struct VoiceEqualizerView: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: 2) {
            bar(delay: 0.0, height: animating ? 12 : 4)
            bar(delay: 0.2, height: animating ? 16 : 6)
            bar(delay: 0.4, height: animating ? 10 : 3)
        }
        .frame(width: 14, height: 16)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
    
    private func bar(delay: Double, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.purple)
            .frame(width: 2.5, height: height)
    }
}
