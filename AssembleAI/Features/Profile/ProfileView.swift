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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    viewModel.showEditProfileSheet = true
                }
                .font(.body)
                .foregroundColor(.assembleBrandPrimary)
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
        .alert("Delete Account & All Data?", isPresented: $viewModel.showDeleteAccountDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) {
                viewModel.deleteAccount(authService: authService, modelContext: modelContext) {
                    router.transitionToWelcome()
                }
            }
        } message: {
            Text("This will permanently delete your account, session records, and authentication tokens. This action cannot be undone.")
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
                    .fill(activeColor.opacity(0.12))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(activeColor.opacity(0.25), lineWidth: 1)
                    )
                
                Image(systemName: viewModel.avatarSymbol)
                    .font(.system(size: 26, weight: .medium))
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
                
                // Status Indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isGuest ? AppColors.warning : AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isGuest ? "Guest Mode (Local)" : "Synced to Supabase")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .appCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.displayName), \(viewModel.email), Status: \(viewModel.isGuest ? "Guest Mode" : "Synced to Supabase")")
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            StatTile(title: "Sessions", value: "\(viewModel.completedSessionsCount)", icon: "checkmark.circle.fill", iconColor: AppColors.statusSuccess)
            StatTile(title: "Accuracy", value: "\(viewModel.overallAccuracyScore)%", icon: "target", iconColor: .assembleBrandPrimary)
            StatTile(title: "Time", value: "\(viewModel.totalAssemblyMinutes)m", icon: "clock.fill", iconColor: AppColors.statusWarning)
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Preferences & Tools")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                NavigationLink(value: ProfileNavigationDestination.appSettings) {
                    settingLinkRow(icon: "slider.horizontal.3", title: "App Settings", subtitle: "Guidance level, camera HUD, haptics", color: .assembleBrandPrimary)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    settingLinkRow(icon: "lock.shield.fill", title: "Data & Privacy", subtitle: "On-device cache, research CSV export", color: AppColors.statusSuccess)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.notifications) {
                    settingLinkRow(icon: "bell.fill", title: "Notifications", subtitle: "Reminders & daily building streak", color: AppColors.statusWarning)
                }
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.help) {
                    settingLinkRow(icon: "book.pages.fill", title: "Assembly Guide & FAQ", subtitle: "Hardware pinouts, conventions, tips", color: Color(uiColor: .secondaryLabel))
                }
            }
            .appCard(padding: 0)
        }
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Button(role: .destructive) {
                viewModel.showSignOutDialog = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                    Spacer()
                }
                .frame(minHeight: 48)
                .background(AppColors.secondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(role: .destructive) {
                viewModel.showDeleteAccountDialog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text("Delete Account & Data")
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.error.opacity(0.85))
                .padding(.vertical, 8)
            }
            
            // Legal & Privacy Compliance Links (App Store Guideline 5.1.1)
            HStack(spacing: AppSpacing.md) {
                Link("Privacy Policy", destination: URL(string: "https://assembleai.app/privacy")!)
                Text("•")
                    .foregroundColor(AppColors.tertiaryText)
                Link("Terms of Service", destination: URL(string: "https://assembleai.app/terms")!)
            }
            .font(.caption2)
            .foregroundColor(AppColors.secondaryText)
            .padding(.top, AppSpacing.xs)
        }
        .padding(.top, AppSpacing.xs)
    }
    
    private func settingLinkRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
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
                .font(.caption.weight(.semibold))
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
