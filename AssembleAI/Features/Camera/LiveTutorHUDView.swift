//
//  LiveTutorHUDView.swift
//  AssembleAI
//

import SwiftUI

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

/// Floating, compact Live Tutor HUD overlay presenting real-time conversational guidance, voice controls, and status pills.
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
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Floating Assistant Glass Card
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Card Header: Status Badge & Pause/Resume Control
                HStack {
                    statusBadge
                    
                    Spacer()
                    
                    // Pause / Resume Button
                    Button(action: onTogglePause) {
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
                    .strokeBorder(cardBorderColor.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            
            // Bottom Controls Bar: Tap-to-Talk Button & Secondary Actions
            HStack(spacing: AppSpacing.md) {
                // Tap-to-Talk Button
                Button(action: onToggleVoice) {
                    HStack(spacing: 8) {
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(isListening ? "Listening..." : "Talk")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(isListening ? AppColors.error : Color.assembleBrandPrimary)
                    )
                }
                .accessibilityLabel(isListening ? "Stop listening" : "Talk to AssembleAI")
                
                // Manual Capture Fallback (if user desires explicit snapshot)
                if let onManualFallback = onManualFallback {
                    Button(action: onManualFallback) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .accessibilityLabel("Manual snapshot analysis")
                }
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(reduceMotion ? 1.0 : (status == .live || status == .speaking || status == .listening ? (isPulsing ? 1.2 : 0.8) : 1.0))
            
            Text(status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("AssembleAI")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(.ultraThinMaterial))
    }
    
    private func assistantMessageView(_ message: TutorResponse) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundColor(AppColors.warning)
            
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
    
    private var statusColor: Color {
        switch status {
        case .live: return AppColors.success
        case .paused: return Color.gray
        case .speaking: return Color.purple
        case .listening: return AppColors.warning
        case .verifying: return Color.assembleBrandPrimary
        }
    }
    
    private var cardBorderColor: Color {
        switch status {
        case .live: return Color.white.opacity(0.2)
        case .paused: return Color.gray
        case .speaking: return Color.purple
        case .listening: return AppColors.warning
        case .verifying: return Color.assembleBrandPrimary
        }
    }
}
