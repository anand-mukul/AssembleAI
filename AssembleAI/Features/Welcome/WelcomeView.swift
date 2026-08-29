//
//  WelcomeView.swift
//  AssembleAI
//

import SwiftUI

/// First primary launch screen introducing AssembleAI's camera verification guidance capabilities.
struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var rowsAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Spacious Header Section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("AssembleAI")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.assembleBrandPrimary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("State-Aware\nTask Guidance")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Visual verification for physical assembly tasks. Follow instructions, observe state, and verify each step on-device.")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, AppSpacing.xxl)
                
                // Camera Inspection Visual Centerpiece
                AssemblyCameraMotifView()
                    .padding(.vertical, AppSpacing.sm)
                
                // Capability Feature Rows
                VStack(spacing: AppSpacing.mdLg) {
                    ForEach(Array(capabilities.enumerated()), id: \.offset) { index, cap in
                        CapabilityRow(
                            iconName: cap.icon,
                            title: cap.title,
                            subtitle: cap.subtitle
                        )
                        .opacity(rowsAppeared ? 1 : 0)
                        .offset(y: rowsAppeared ? 0 : 12)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.1),
                            value: rowsAppeared
                        )
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, 120)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .onAppear {
            rowsAppeared = true
        }
    }
    
    private var capabilities: [(icon: String, title: String, subtitle: String)] {
        [
            ("viewfinder", "Observe & Scan", "Compare assembly progress against expected task states using your iPhone camera."),
            ("list.bullet.rectangle", "Sequential Guidance", "Follow precise step-by-step instructions tailored to electronic and mechanical builds."),
            ("checkmark.shield", "On-Device Verification", "Verify step completion locally with full privacy. No data leaves your device.")
        ]
    }
    
    private var bottomActions: some View {
        VStack(spacing: AppSpacing.mdSm) {
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
        .padding(.horizontal, AppSpacing.screenEdge)
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
                .font(.body.weight(.medium))
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
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
        .accessibilityElement(children: .combine)
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
