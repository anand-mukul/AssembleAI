//
//  HomeView.swift
//  AssembleAI
//

import SwiftUI

/// Main Home screen displaying active physical assembly progress, project cards, and recent step activity.
@MainActor
struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()
    
    /// Callback to request switching to the Projects tab from MainTabView
    var onSelectProjectsTab: (() -> Void)? = nil
    var onSelectProject: ((AssemblyProject) -> Void)? = nil
    
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Dynamic Greeting Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.greetingText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Ready for your next physical assembly task.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.screenEdge)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 6)
                
                // Error Alert Banner with Retry
                if let error = viewModel.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unable to load projects")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.primaryText)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadContent()
                            }
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(Color.assembleBrandPrimary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .strokeBorder(AppColors.error.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, AppSpacing.screenEdge)
                }
                
                // Active Project Centerpiece OR Empty Active State
                Group {
                    if let activeProject = viewModel.activeProject {
                        ActiveProjectCard(
                            project: activeProject,
                            onContinue: {
                                if let onSelectProject = onSelectProject {
                                    onSelectProject(activeProject)
                                }
                            }
                        )
                    } else {
                        noActiveProjectCard
                    }
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
                
                // Your Projects Section Header & Cards
                VStack(alignment: .leading, spacing: AppSpacing.mdSm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your Projects")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelectProjectsTab?()
                        }) {
                            HStack(spacing: 4) {
                                Text("See All")
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.assembleBrandPrimary)
                        }
                        .touchTarget()
                        .accessibilityLabel("See all projects")
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                    
                    // Recent Project Cards
                    if viewModel.recentProjects.isEmpty {
                        Text("No other projects available.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.tertiaryText)
                            .padding(.horizontal, AppSpacing.screenEdge)
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(viewModel.recentProjects, id: \.id) { project in
                                ProjectCard(
                                    project: project,
                                    onTap: {
                                        if let onSelectProject = onSelectProject {
                                            onSelectProject(project)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
                
                // Recent Activity Section
                if !viewModel.recentActivity.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Recent Activity")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, AppSpacing.screenEdge)
                        
                        VStack(spacing: 0) {
                            ForEach(viewModel.recentActivity, id: \.id) { activity in
                                ActivityItemRow(activity: activity)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                
                                if activity.id != viewModel.recentActivity.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .appCard(padding: 0)
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                }
            }
            .padding(.bottom, 100)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("AssembleAI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.assembleBrandPrimary)
                    Text("AssembleAI")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryText)
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                hasAppeared = true
            }
            Task {
                await viewModel.loadContent()
            }
        }
        .task {
            await viewModel.loadContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssemblySessionUpdated"))) { _ in
            Task {
                await viewModel.loadContent()
            }
        }
        .refreshable {
            await viewModel.loadContent()
        }
    }
    
    // MARK: - No Active Project Fallback Card
    
    private var noActiveProjectCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                SemanticIconBadge(iconName: "wrench.and.screwdriver.fill", size: 30, iconSize: 15, color: AppColors.badgeOrange)
                
                Text("Ready to assemble?")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
            }
            
            Text("Select a hardware task to begin guided step-by-step assembly.")
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .adaptiveMultiline()
            
            SecondaryButton(title: "Explore Projects", iconName: "folder") {
                onSelectProjectsTab?()
            }
            .padding(.top, AppSpacing.xs)
        }
        .appCard()
    }
}

#Preview("Home View - Active Project") {
    HomeView()
        .environmentObject(AppRouter())
}
