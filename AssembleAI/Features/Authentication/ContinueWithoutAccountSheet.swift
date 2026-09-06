//
//  ContinueWithoutAccountSheet.swift
//  AssembleAI
//

import SwiftUI

/// Confirmation sheet modal for guest access respecting local privacy preferences.
struct ContinueWithoutAccountSheet: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Header: Top breathing space + strictly centered icon & titles
            VStack(spacing: AppSpacing.sm) {
                AnimatedHeaderIcon(
                    iconName: "iphone.circle.fill",
                    iconSize: 36,
                    circleDiameter: 72,
                    useGradient: false,
                    staticColor: AppColors.badgeBlue
                )
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Continue on iPhone")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Use AssembleAI without an account. Your assembly projects and inspection history stay strictly on this device.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .adaptiveMultiline()
                        .padding(.horizontal, AppSpacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 28)
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer(minLength: AppSpacing.md)
            
            // Actions
            VStack(spacing: AppSpacing.xs) {
                PrimaryButton(title: "Continue", iconName: "arrow.right") {
                    dismiss()
                    Task {
                        await authService.continueAsGuest()
                        router.transitionToHome()
                    }
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Sign in instead")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.sheet)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Continue Without Account Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            ContinueWithoutAccountSheet()
                .environmentObject(AppRouter())
                .environmentObject(SupabaseAuthService())
        }
}
