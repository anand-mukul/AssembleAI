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
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            
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
                                .font(.body.weight(.semibold))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.body.weight(.semibold))
                            Text("Talk to AssembleAI")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(isListening ? AppColors.statusListening : Color.assembleBrandPrimary)
                    )
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
                            .frame(width: 48, height: 48)
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
            ThinkingOrbView(status: status, diameter: 14)
            
            Text(status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(.ultraThinMaterial))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.rawValue)")
    }
    
    private func assistantMessageView(_ message: TutorResponse) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if status == .speaking {
                VoiceEqualizerView()
                    .padding(.top, 3)
            } else if message.priority == .high || message.category == "correction" {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.statusWarning)
                    .padding(.top, 2)
            } else if message.category == "confirmation" {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.statusSuccess)
                    .padding(.top, 2)
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
        case .live: return AppColors.statusLive
        case .paused: return AppColors.statusPaused
        case .speaking: return AppColors.statusSpeaking
        case .listening: return AppColors.statusListening
        case .verifying: return AppColors.statusVerifying
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
            .fill(AppColors.statusSpeaking)
            .frame(width: 2.5, height: height)
    }
}

