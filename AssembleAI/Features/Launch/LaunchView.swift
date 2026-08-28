//
//  LaunchView.swift
//  AssembleAI
//

import SwiftUI

/// Launch screen providing a short branded experience while determining initial app state.
struct LaunchView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: CloudKitAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.94
    
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    router.completeLaunch(isAuthenticated: authService.isAuthenticated)
                }
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    router.completeLaunch(isAuthenticated: authService.isAuthenticated)
                }
            }
        }
    }
}

#Preview("Launch View") {
    LaunchView()
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}

#Preview("Launch View - Dark Mode") {
    LaunchView()
        .preferredColorScheme(.dark)
        .environmentObject(AppRouter())
        .environmentObject(CloudKitAuthService())
}
