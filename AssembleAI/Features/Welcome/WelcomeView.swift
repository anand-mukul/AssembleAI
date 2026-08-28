//
//  WelcomeView.swift
//  AssembleAI
//

import SwiftUI

/// First primary screen introducing AssembleAI's visual guidance capabilities.
struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppSpacing.md)
            
            // Header & Brand Mark
            VStack(spacing: AppSpacing.sm) {
                Text("AssembleAI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Build with confidence.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.bottom, AppSpacing.lg)
            
            // Visual Camera/Assembly Motif
            AssemblyCameraMotifView()
                .padding(.horizontal, AppSpacing.md)
            
            Spacer(minLength: AppSpacing.md)
            
            // Core Value Proposition Copy
            VStack(spacing: AppSpacing.sm) {
                Text("Your visual guide for physical tasks and assembly.")
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.primaryText)
                    .padding(.horizontal, AppSpacing.lg)
                
                HStack(spacing: AppSpacing.xs) {
                    Text("Observe")
                    Text("•")
                        .foregroundColor(AppColors.tertiaryText)
                    Text("Understand")
                    Text("•")
                        .foregroundColor(AppColors.tertiaryText)
                    Text("Verify")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.assembleBrandPrimary)
            }
            .padding(.bottom, AppSpacing.xl)
            
            // Action Buttons
            VStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Get Started", iconName: "arrow.right") {
                    router.navigateToAuthChoice()
                }
                
                Button(action: {
                    router.navigateToSignIn()
                }) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(AppColors.secondaryText)
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.assembleBrandPrimary)
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, AppSpacing.xs)
                .accessibilityLabel("Already have an account? Sign In")
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
}

#Preview("Welcome View") {
    WelcomeView()
        .environmentObject(AppRouter())
}

#Preview("Welcome View - Dark Mode") {
    WelcomeView()
        .preferredColorScheme(.dark)
        .environmentObject(AppRouter())
}
