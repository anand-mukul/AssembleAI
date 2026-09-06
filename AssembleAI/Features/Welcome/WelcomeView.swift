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
            // Subtle studio lighting backdrop
            GradientAtmosphereBackground(intensity: .hero)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    // Orbital Hero Section
                    OrbitalHeroView()
                        .padding(.top, AppSpacing.sm)
                    
                    // Hero Typography
                    VStack(spacing: AppSpacing.xs) {
                        Text("Build with precision.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("AI-Powered Hardware Assembly")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)
                    
                    // Feature Cards
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(capabilities.enumerated()), id: \.offset) { index, cap in
                            GlassmorphicFeatureCard(
                                iconName: cap.icon,
                                title: cap.title,
                                subtitle: cap.subtitle,
                                iconColor: cap.color,
                                showDisclosure: cap.icon == "lock.shield",
                                onTap: cap.icon == "lock.shield" ? {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showPrivacySheet = true
                                } : nil
                            )
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 6)
                            .animation(
                                reduceMotion ? .none : AppAnimation.entranceSpring.delay(Double(index) * AppAnimation.staggerDelay + 0.15),
                                value: contentAppeared
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                }
                .padding(.bottom, AppSpacing.xxl)
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
    
    private var capabilities: [(icon: String, title: String, subtitle: String, color: Color)] {
        [
            ("viewfinder", "Live Guidance", "Follows your hands as you build and highlights where each component connects.", AppColors.badgeBlue),
            ("checkmark.seal", "Physical Verification", "Confirms pin positions, wire rows, and polarities before you power on.", AppColors.badgeGreen),
            ("lock.shield", "Private & On-Device", "All camera processing stays strictly on your iPhone. Zero cloud uploads.", AppColors.badgeIndigo)
        ]
    }
    
    private var bottomActions: some View {
        VStack(spacing: AppSpacing.sm) {
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
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
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
