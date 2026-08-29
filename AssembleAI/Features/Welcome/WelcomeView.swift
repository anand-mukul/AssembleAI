//
//  WelcomeView.swift
//  AssembleAI
//

import SwiftUI

/// First primary screen introducing AssembleAI's visual guidance capabilities.
struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                    .padding(.top, AppSpacing.xl)
                
                AssemblyCameraMotifView()
                
                valueProposition
                capabilityList
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, 128)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            BrandHeaderView(size: .compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Visual guidance for hands-on work")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Follow assembly workflows, verify each state, and keep project history available on-device or synced when you sign in.")
                .font(.body)
                .foregroundColor(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var valueProposition: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Built for the bench")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            Text("A quiet, step-by-step workspace for physical tasks where clarity matters more than decoration.")
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
        }
    }
    
    private var capabilityList: some View {
        VStack(spacing: AppSpacing.md) {
            CapabilityRow(iconName: "viewfinder", title: "Observe", subtitle: "Use visual checkpoints to compare the current state.")
            CapabilityRow(iconName: "list.bullet.rectangle", title: "Guide", subtitle: "Keep instructions, timing, and difficulty in one workflow.")
            CapabilityRow(iconName: "checkmark.seal", title: "Verify", subtitle: "Track progress locally and sync when an account is available.")
        }
    }
    
    private var bottomActions: some View {
        VStack(spacing: AppSpacing.md) {
            PrimaryButton(title: "Get Started", iconName: "arrow.right") {
                router.navigateToAuthChoice()
            }
            
            Button(action: {
                router.navigateToSignIn()
            }) {
                HStack(spacing: AppSpacing.xs) {
                    Text("Already have an account?")
                        .foregroundColor(AppColors.secondaryText)
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                }
                .font(.subheadline)
            }
            .accessibilityLabel("Already have an account? Sign In")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(.regularMaterial)
    }
}

private struct CapabilityRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
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
