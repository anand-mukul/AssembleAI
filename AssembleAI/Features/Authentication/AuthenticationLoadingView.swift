//
//  AuthenticationLoadingView.swift
//  AssembleAI
//

import SwiftUI

/// Lightweight loading overlay view for smooth authentication transition states.
struct AuthenticationLoadingView: View {
    var message: String = "Signing you in…"
    
    @State private var pulseGlow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Atmospheric dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            // Glassmorphic Modal Card
            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColors.glowPrimary.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .blur(radius: 14)
                        .scaleEffect(pulseGlow ? 1.2 : 0.9)
                    
                    ProgressView()
                        .scaleEffect(1.25)
                        .tint(AppColors.primaryText)
                }
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
            )
            .shadow(color: AppShadow.mediumColor, radius: 24, x: 0, y: 10)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview("Authentication Loading View") {
    AuthenticationLoadingView()
}
