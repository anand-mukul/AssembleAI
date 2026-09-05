//
//  LaunchView.swift
//  AssembleAI
//

import SwiftUI

/// Launch screen providing a short branded experience while determining initial app state.
struct LaunchView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.94
    @State private var hasMinimumSplashElapsed: Bool = false
    @State private var hasCompletedLaunch: Bool = false
    
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.lg) {
                BrandHeaderView(size: .large)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .onAppear {
            if reduceMotion {
                opacity = 1.0
                scale = 1.0
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 1.0
                    scale = 1.0
                }
            }
            
            Task {
                // Minimum splash duration for brand recognition
                let duration: UInt64 = reduceMotion ? 350_000_000 : 650_000_000
                try? await Task.sleep(nanoseconds: duration)
                hasMinimumSplashElapsed = true
                evaluateTransition()
            }
            
            // Failsafe timeout: never stall indefinitely even if remote check hits edge network timeout
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if !hasCompletedLaunch {
                    hasCompletedLaunch = true
                    router.completeLaunch(isAuthenticated: authService.isAuthenticated)
                }
            }
        }
        .onChange(of: authService.isSessionRestored) { _ in
            evaluateTransition()
        }
    }
    
    private func evaluateTransition() {
        guard !hasCompletedLaunch, hasMinimumSplashElapsed, authService.isSessionRestored else { return }
        hasCompletedLaunch = true
        router.completeLaunch(isAuthenticated: authService.isAuthenticated)
    }
}

#Preview("Launch View") {
    LaunchView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}

#Preview("Launch View - Dark Mode") {
    LaunchView()
        .preferredColorScheme(.dark)
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}
