//
//  WelcomeView.swift
//  AssembleAI
//

import SwiftUI

/// First primary launch screen introducing AssembleAI's camera verification guidance capabilities.
struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var contentAppeared = false
    @State private var showPrivacySheet = false
    
    var body: some View {
        ZStack {
            // Atmosphere background
            GradientAtmosphereBackground(intensity: .hero)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    // Orbital Hero Section
                    OrbitalHeroView()
                        .padding(.top, AppSpacing.md)
                    
                    // Hero Typography
                    VStack(spacing: AppSpacing.sm) {
                        Text("Build with precision.")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                        
                        HStack(spacing: 6) {
                            Text("AI-Powered")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("Hardware Assembly")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .font(.title3)
                        .fontWeight(.medium)
                    }
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    
                    // Glassmorphic Feature Cards
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(capabilities.enumerated()), id: \.offset) { index, cap in
                            GlassmorphicFeatureCard(
                                iconName: cap.icon,
                                title: cap.title,
                                subtitle: cap.subtitle,
                                showDisclosure: cap.icon == "lock.shield",
                                onTap: cap.icon == "lock.shield" ? {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showPrivacySheet = true
                                } : nil
                            )
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 8)
                            .animation(
                                reduceMotion ? .none : AppAnimation.entranceSpring.delay(Double(index) * AppAnimation.staggerDelay + 0.2),
                                value: contentAppeared
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                }
                .padding(.bottom, 130)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacySheet(onContinue: {
                showPrivacySheet = false
            })
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                contentAppeared = true
            }
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
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                router.navigateToAuthChoice()
            }
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .background(.ultraThinMaterial)
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
