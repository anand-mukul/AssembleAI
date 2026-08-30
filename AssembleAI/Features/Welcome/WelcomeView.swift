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
                // Editorial Header Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("ASSEMBLEAI")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                        .padding(.bottom, AppSpacing.xxs)
                        .accessibilityHidden(true)
                    
                    Text("Build with\nprecision.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Real-time camera verification for physical hardware assembly. Point your iPhone at your workspace and verify each step as you build.")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.top, AppSpacing.xl)
                
                // Hardware Inspection Preview Card
                AssemblyCameraMotifView()
                    .padding(.vertical, AppSpacing.xs)
                
                // Physical Capability Pillars (Monochrome, Architectural)
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(capabilities.enumerated()), id: \.offset) { index, cap in
                        CapabilityRow(
                            iconName: cap.icon,
                            title: cap.title,
                            subtitle: cap.subtitle
                        )
                        .opacity(rowsAppeared ? 1 : 0)
                        .offset(y: rowsAppeared ? 0 : 8)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.82).delay(Double(index) * 0.06),
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
            ("viewfinder", "Live Guidance", "Follows your hands as you build and highlights where each component connects."),
            ("checkmark.seal", "Physical Verification", "Confirms pin positions, wire rows, and polarities before you power on."),
            ("lock.shield", "Private & On-Device", "All camera processing stays strictly on your iPhone. Zero cloud uploads.")
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
                        .foregroundColor(AppColors.primaryText)
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
                .foregroundColor(AppColors.primaryText)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
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
