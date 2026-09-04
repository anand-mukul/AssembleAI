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

// MARK: - Live Tutor HUD View (Dual Glass Cards Layout)

/// High-clarity dual-card HUD overlay matching Silicon Valley Apple design standards:
/// Card 1: Step Guide (component name, pin routing chips, and step directive).
/// Card 2: Live Instruction (real-time spoken feedback, voice transcript, and interaction controls).
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
        VStack(spacing: AppSpacing.sm) {
            // MARK: - Card 1: Step Guide Card
            stepGuideCard
            
            // MARK: - Card 2: Live Instruction Card
            liveInstructionCard
        }
    }
    
    // MARK: - Step Guide Card
    
    private var stepGuideCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 8) {
                // Component domain icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(Color.assembleBrandPrimary.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: componentIcon(for: currentStep.title))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                // Card title
                Text(currentStep.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Step Pill Tag
                HStack(spacing: 4) {
                    Text("STEP \(currentStep.stepOrder)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
            }
            
            // Step Instruction Description
            Text(currentStep.instruction)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.mdSm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: AppColors.glassShadow, radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Live Instruction Card
    
    private var liveInstructionCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Status bar header
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
                            .font(.system(size: 10, weight: .bold))
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                    )
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
            
            // Action Control Bar
            HStack(spacing: AppSpacing.sm) {
                // Talk to AssembleAI Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onToggleVoice()
                }) {
                    HStack(spacing: 8) {
                        if isListening {
                            ThinkingOrbView(status: .listening, diameter: 18, customColor: .white)
                            Text("Listening...")
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.subheadline.weight(.semibold))
                            Text("Talk to AssembleAI")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(isListening ? AppColors.statusListening : Color.assembleBrandPrimary)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isListening ? "Stop listening" : "Talk to AssembleAI")
                
                // Snapshot Fallback Button
                if let onManualFallback = onManualFallback {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onManualFallback()
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Manual snapshot analysis")
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.mdSm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: AppColors.glassShadow, radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Subviews & Indicators
    
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
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
        )
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                if message.category == "correction", let onExplainWhy = onExplainWhy {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onExplainWhy()
                    }) {
                        HStack(spacing: 4) {
                            Text("Why is this wrong?")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(Color.assembleBrandPrimary)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
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
        .padding(.vertical, 2)
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
        .padding(.vertical, 2)
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
