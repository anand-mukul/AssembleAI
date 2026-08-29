//
//  WelcomeView.swift
//  AssembleAI
//

import SwiftUI

/// First primary launch screen introducing AssembleAI's camera verification guidance capabilities.
struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Spacious Header Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("AssembleAI")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.assembleBrandPrimary)
                        .textCase(.uppercase)
                    
                    Text("State-Aware Task Guidance")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Visual verification for physical assembly tasks. Observe your workspace, follow instructions, and verify each step.")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.lg)
                
                // Camera Inspection Visual Centerpiece
                AssemblyCameraMotifView()
                    .padding(.vertical, AppSpacing.xs)
                
                // Capability Feature Rows
                VStack(spacing: AppSpacing.md) {
                    CapabilityRow(
                        iconName: "viewfinder",
                        title: "Observe & Scan",
                        subtitle: "Compare physical assembly progress against expected task states."
                    )
                    
                    CapabilityRow(
                        iconName: "list.bullet.rectangle",
                        title: "Sequential Guidance",
                        subtitle: "Follow precise instructions tailored to electronic and mechanical builds."
                    )
                    
                    CapabilityRow(
                        iconName: "checkmark.shield",
                        title: "State Verification",
                        subtitle: "Verify step completion locally with full on-device privacy."
                    )
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, 120)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActions
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
                HStack(spacing: 4) {
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
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
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
