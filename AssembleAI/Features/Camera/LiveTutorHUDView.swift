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

// MARK: - Live Tutor HUD View (Apple Vision Pro / iOS 18 Dynamic Island HUD)

/// High-clarity unified floating glass island overlay matching Apple HIG & Vision Pro standards:
/// - Header: Component icon badge, step indicator, and quick pause/resume control.
/// - Adaptive Body: Crisp step directive, real-time AI spoken feedback, or active voice transcript.
/// - Action Controls: Apple Intelligence voice interaction capsule and manual snapshot button.
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
    var onExplainWhy: (() -> Void)? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        unifiedIslandHUD
    }
    
    // MARK: - Unified Glass Island Layout
    
    private var unifiedIslandHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Status Badge + Step Badge + Component Title + Secondary Controls
            HStack(alignment: .center, spacing: 7) {
                // Live Status Pill
                HStack(spacing: 5) {
                    ThinkingOrbView(status: status, diameter: 10)
                    Text(status.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                
                // Step Badge Pill
                HStack(spacing: 4) {
                    Image(systemName: componentIcon(for: currentStep.title))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.assembleBrandPrimary)
                    Text("STEP \(currentStep.stepOrder)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                
                // Component / Step Title
                Text(currentStep.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Why Explanation (if correction)
                if currentMessage?.category == "correction", let onExplainWhy = onExplainWhy {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onExplainWhy()
                    }) {
                        HStack(spacing: 3) {
                            Text("Why?")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(Color.assembleBrandPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.assembleBrandPrimary.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Color.assembleBrandPrimary.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Why is this step wrong?")
                }
                
                // Pause / Resume Button (clean compact glass pill)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTogglePause()
                }) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isPaused ? "Resume Live Tutor" : "Pause Live Tutor")
            }
            
            // Middle Content: Adaptive Instruction / AI Spoken Feedback / Transcript
            Group {
                if isListening {
                    userTranscriptView
                } else if let message = currentMessage {
                    assistantMessageView(message)
                } else {
                    stepInstructionView
                }
            }
            .padding(.vertical, 2)
            
            // Bottom Action Row: Siri Voice Pill + Snapshot Button
            HStack(spacing: 10) {
                // Talk to AssembleAI Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onToggleVoice()
                }) {
                    HStack(spacing: 8) {
                        if isListening {
                            ThinkingOrbView(status: .listening, diameter: 16, customColor: .white)
                            Text("Listening...")
                                .font(.subheadline.weight(.semibold))
                        } else if status == .speaking {
                            VoiceEqualizerView()
                            Text("AssembleAI is speaking...")
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Talk to AssembleAI")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        ZStack {
                            if isListening {
                                LinearGradient(
                                    colors: [AppColors.aiCyan, AppColors.aiBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.assembleBrandPrimary)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: isListening ? AppColors.aiBlue.opacity(0.35) : Color.assembleBrandPrimary.opacity(0.28), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isListening ? "Stop listening" : "Talk to AssembleAI")
                
                // Manual Snapshot Button
                if let onManualFallback = onManualFallback {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onManualFallback()
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Manual snapshot analysis")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.40))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 6)
    }
    
    // MARK: - Subviews & Indicators
    
    private var stepInstructionView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isPaused ? "pause.circle" : "eye.fill")
                .font(.caption)
                .foregroundColor(isPaused ? .secondary : Color.assembleBrandPrimary.opacity(0.85))
                .padding(.top, 2)
            
            Text(currentStep.instruction)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.90))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    private func assistantMessageView(_ message: TutorResponse) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if status == .speaking {
                VoiceEqualizerView()
                    .padding(.top, 3)
            } else if message.priority == .high || message.category == "correction" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.statusWarning)
                    .padding(.top, 2)
            } else if message.category == "confirmation" {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.statusSuccess)
                    .padding(.top, 2)
            } else {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(Color.assembleBrandPrimary)
                    .padding(.top, 2)
            }
            
            Text(message.text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
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
    }
    
    private func componentIcon(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("resistor") {
            return "resistor"
        } else if lower.contains("capacitor") {
            return "batteryblock.fill"
        } else if lower.contains("led") || lower.contains("diode") {
            return "lightbulb.fill"
        } else if lower.contains("ic") || lower.contains("chip") || lower.contains("555") {
            return "cpu"
        } else if lower.contains("wire") || lower.contains("jumper") {
            return "waveform.path"
        } else {
            return "wrench.and.screwdriver.fill"
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
