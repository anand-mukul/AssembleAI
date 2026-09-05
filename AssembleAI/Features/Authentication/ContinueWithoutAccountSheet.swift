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
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 8)
            
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "iphone.circle.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                }
                .padding(.bottom, AppSpacing.xxs)
                
                Text("Continue on iPhone")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Use AssembleAI without an account. Your assembly projects and inspection history stay strictly on this device.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.sm)
            }
            
            Spacer(minLength: 12)
            
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
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .presentationDetents([.height(400), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
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
