//
//  ProfilePlaceholderView.swift
//  AssembleAI
//

import SwiftUI

/// Account & Profile settings view providing cloud sync status, privacy governance, and sign out options.
struct ProfilePlaceholderView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // User Profile Summary Card
                VStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.assembleBrandPrimary.opacity(0.1))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.assembleBrandPrimary)
                    }
                    
                    VStack(spacing: 2) {
                        Text(authService.currentUser?.displayName ?? "Assembly Engineer")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(authService.currentUser?.email ?? "Guest User")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(authService.currentUser?.isGuest == true ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(authService.currentUser?.isGuest == true ? "Guest (Local Storage)" : "Supabase Cloud Synced")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.tertiaryBackground))
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                )
                
                // Privacy & Data Governance Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("PRIVACY & DATA GOVERNANCE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                    
                    VStack(spacing: 0) {
                        privacyStatusRow(label: "Camera Access", value: "System controlled", icon: "camera.fill", color: .green)
                        Divider().padding(.leading, 44)
                        privacyStatusRow(label: "Local Processing", value: "Enabled (On-Device)", icon: "cpu.fill", color: .blue)
                        Divider().padding(.leading, 44)
                        privacyStatusRow(label: "Research Data", value: "Stored on this device", icon: "lock.shield.fill", color: .indigo)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Account Settings Links
                VStack(spacing: 0) {
                    profileLinkRow(icon: "bell", title: "Notifications", subtitle: "Task completion reminders")
                    Divider().padding(.leading, 44)
                    profileLinkRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Hardware assembly guides")
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
                )
                
                // Sign Out
                SecondaryButton(title: "Sign Out", iconName: "rectangle.portrait.and.arrow.right") {
                    Task {
                        await authService.signOut()
                        router.transitionToWelcome()
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func privacyStatusRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppSpacing.md)
    }
    
    private func profileLinkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(AppSpacing.md)
    }
}

#Preview("Profile View") {
    NavigationStack {
        ProfilePlaceholderView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
