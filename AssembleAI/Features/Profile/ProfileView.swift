//
//  ProfileView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

/// Comprehensive native iOS Profile & Settings screen presenting user metadata, assembly metrics, navigation links, and session management.
struct ProfileView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Profile Hero Card
                profileHeroCard
                
                // Aggregate Metrics Grid
                metricsGrid
                
                // Settings & Preferences Navigation Section
                settingsSection
                
                // Account Actions
                accountActionsSection
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.showEditProfileSheet = true
                }) {
                    Text("Edit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(activeColor)
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditProfileSheet) {
            EditProfileSheet(viewModel: viewModel)
        }
        .alert("Sign Out of AssembleAI?", isPresented: $viewModel.showSignOutDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                    router.transitionToWelcome()
                }
            }
        } message: {
            Text("Your local progress will be saved on this device.")
        }
        .task {
            viewModel.updateUser(user: authService.currentUser)
            let sessionRepo = LocalFirstSessionRepository(modelContext: modelContext)
            await viewModel.loadSessionMetrics(sessionRepository: sessionRepo)
        }
        .onChange(of: authService.currentUser) { _, newUser in
            viewModel.updateUser(user: newUser)
        }
    }
    
    // MARK: - Subviews
    
    private var activeColor: Color {
        ProfileViewModel.availableColors.first { $0.hex == viewModel.avatarColorHex }?.color ?? Color.assembleBrandPrimary
    }
    
    private var profileHeroCard: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(activeColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(activeColor.opacity(0.35), lineWidth: 2)
                    )
                
                Image(systemName: viewModel.avatarSymbol)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(activeColor)
            }
            
            // Name & Email
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(viewModel.email)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                
                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isGuest ? AppColors.warning : AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isGuest ? "GUEST MODE (LOCAL)" : "SYNCED TO SUPABASE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.isGuest ? AppColors.warning : AppColors.success)
                }
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
        )
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            metricTile(title: "SESSIONS", value: "\(viewModel.completedSessionsCount)", icon: "checkmark.circle.fill", color: AppColors.success)
            metricTile(title: "ACCURACY", value: "\(viewModel.overallAccuracyScore)%", icon: "target", color: .indigo)
            metricTile(title: "TIME", value: "\(viewModel.totalAssemblyMinutes)m", icon: "clock.fill", color: .orange)
        }
    }
    
    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("PREFERENCES & TOOLS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)
                .tracking(1.0)
            
            VStack(spacing: 0) {
                NavigationLink(value: ProfileNavigationDestination.appSettings) {
                    settingLinkRow(icon: "slider.horizontal.3", title: "App Settings", subtitle: "Guidance level, camera HUD, haptics", color: .assembleBrandPrimary)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    settingLinkRow(icon: "lock.shield.fill", title: "Data & Privacy", subtitle: "On-device cache, research CSV export", color: AppColors.success)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.notifications) {
                    settingLinkRow(icon: "bell.fill", title: "Notifications", subtitle: "Reminders & daily building streak", color: .orange)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.help) {
                    settingLinkRow(icon: "book.pages.fill", title: "Assembly Guide & FAQ", subtitle: "Hardware pinouts, conventions, tips", color: .indigo)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
            )
        }
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            SecondaryButton(title: "Sign Out", iconName: "rectangle.portrait.and.arrow.right") {
                viewModel.showSignOutDialog = true
            }
        }
        .padding(.top, AppSpacing.xs)
    }
    
    private func settingLinkRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
            }
            
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
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(AppSpacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Navigation Destinations Enum

enum ProfileNavigationDestination: Hashable {
    case appSettings
    case dataPrivacy
    case notifications
    case help
}

#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(AppRouter())
            .environmentObject(SupabaseAuthService())
    }
}
