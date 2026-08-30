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
                // Calm, Airy Header Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.statusLive)
                            .frame(width: 7, height: 7)
                        Text("ASSEMBLEAI")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.2)
                    }
                    .padding(.bottom, AppSpacing.xxs)
                    .accessibilityHidden(true)
                    
                    Text("Assemble with\nconfidence.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("A quiet visual guide that watches your hands as you build, confirming each step in real time.")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.top, AppSpacing.xl)
                
                // Serene, Ambient Visual Centerpiece
                AssemblyCameraMotifView()
                    .padding(.vertical, AppSpacing.xs)
                
                // Calm Capability Pillars
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(capabilities.enumerated()), id: \.offset) { index, cap in
                        CapabilityRow(
                            iconName: cap.icon,
                            title: cap.title,
                            subtitle: cap.subtitle
                        )
                        .opacity(rowsAppeared ? 1 : 0)
                        .offset(y: rowsAppeared ? 0 : 10)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.08),
                            value: rowsAppeared
                        )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, 110)
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
            ("eye.fill", "Live Observation", "Quietly watches your workspace to understand what you're assembling."),
            ("checkmark.shield.fill", "Step Verification", "Confirms every component and wire is in place before you move ahead."),
            ("lock.shield.fill", "Private & On-Device", "All visual intelligence runs locally. No camera frames ever leave your iPhone.")
        ]
    }
    
    private var bottomActions: some View {
        VStack(spacing: AppSpacing.mdSm) {
            PrimaryButton(title: "Get Started") {
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
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
                .font(.system(size: 16, weight: .semibold))
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
