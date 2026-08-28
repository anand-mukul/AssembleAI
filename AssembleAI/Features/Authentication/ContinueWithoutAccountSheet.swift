//
//  ContinueWithoutAccountSheet.swift
//  AssembleAI
//

import SwiftUI

/// Confirmation sheet modal for guest access respecting local privacy preferences.
struct ContinueWithoutAccountSheet: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: CloudKitAuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Drag indicator visual spacer
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "iphone.circle.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
                    .padding(.bottom, AppSpacing.xs)
                
                Text("Continue on this iPhone?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text("You can use AssembleAI without an account. Your projects and history will remain on this device.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            .padding(.top, AppSpacing.sm)
            
            Spacer()
            
            VStack(spacing: AppSpacing.md) {
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
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .presentationDetents([.height(380), .medium])
        .presentationCornerRadius(28)
    }
}

#Preview("Continue Without Account Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            ContinueWithoutAccountSheet()
                .environmentObject(AppRouter())
                .environmentObject(CloudKitAuthService())
        }
}
