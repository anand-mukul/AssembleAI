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
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
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
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    viewModel.showEditProfileSheet = true
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.assembleBrandPrimary)
            }
        }
        .sheet(isPresented: $viewModel.showEditProfileSheet) {
            EditProfileSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacySheet(onContinue: {
                showPrivacySheet = false
            })
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceSheet(onContinue: {
                showTermsSheet = false
            })
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
        .navigationDestination(for: ProfileNavigationDestination.self) { dest in
            switch dest {
            case .appSettings:
                AppSettingsView(viewModel: viewModel)
            case .dataPrivacy:
                DataPrivacySettingsView(viewModel: viewModel)
            case .notifications:
                NotificationsSettingsView(viewModel: viewModel)
            case .help:
                HelpAndSupportView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var activeColor: Color {
        ProfileViewModel.availableColors.first { $0.hex == viewModel.avatarColorHex }?.color ?? Color.assembleBrandPrimary
    }
    
    private var profileHeroCard: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar with ambient aura
            ZStack {
                Circle()
                    .fill(activeColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(activeColor.opacity(0.3), lineWidth: 1)
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
                
                // Status Indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isGuest ? AppColors.warning : AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isGuest ? "Guest Mode (Local)" : "Synced to Supabase")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((viewModel.isGuest ? AppColors.warning : AppColors.success).opacity(0.1))
                )
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
                    settingLinkRow(
                        icon: "slider.horizontal.3",
                        title: "App Settings",
                        subtitle: "Guidance level, camera HUD, haptics",
                        colors: [Color.assembleBrandPrimary, Color.assembleBrandPrimary.opacity(0.8)]
                    )
                }
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    settingLinkRow(
                        icon: "lock.shield.fill",
                        title: "Data & Privacy",
                        subtitle: "On-device cache, research CSV export",
                        colors: [AppColors.statusSuccess, AppColors.statusSuccess.opacity(0.8)]
                    )
                }
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.notifications) {
                    settingLinkRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "Reminders & daily building streak",
                        colors: [AppColors.statusWarning, AppColors.statusWarning.opacity(0.8)]
                    )
                }
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.help) {
                    settingLinkRow(
                        icon: "book.pages.fill",
                        title: "Assembly Guide & FAQ",
                        subtitle: "Hardware pinouts, conventions, tips",
                        colors: [Color(white: 0.5), Color(white: 0.4)]
                    )
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
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body.weight(.medium))
                    Text("Sign Out")
                        .font(.body)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(AppColors.error)
                .frame(minHeight: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(AppColors.error.opacity(0.3), lineWidth: 0.5)
                )
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .touchTarget()
            
            // Legal & Privacy Compliance (App Store Guideline 5.1.1 & 2.1 - In-App Self-Contained)
            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPrivacySheet = true
                }) {
                    Text("Privacy Policy")
                        .underline()
                        .padding(.vertical, AppSpacing.xs)
                }
                .touchTarget()
                
                Text("•")
                    .foregroundColor(AppColors.tertiaryText)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showTermsSheet = true
                }) {
                    Text("Terms of Service")
                        .underline()
                        .padding(.vertical, AppSpacing.xs)
                }
                .touchTarget()
            }
            .font(.caption)
            .foregroundColor(AppColors.secondaryText)
            .padding(.top, AppSpacing.xs)
        }
        .padding(.top, AppSpacing.xs)
    }
    
    private func settingLinkRow(icon: String, title: String, subtitle: String, colors: [Color]) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            GradientIconBadge(iconName: icon, size: 34, iconSize: 15, colors: colors)
            
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
