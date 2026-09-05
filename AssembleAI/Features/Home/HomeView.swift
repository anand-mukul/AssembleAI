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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Dynamic Greeting Header
                VStack(alignment: .leading, spacing: 2) {
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
                
                // Active Project Centerpiece OR Empty Active State
                if let activeProject = viewModel.activeProject {
                    ActiveProjectCard(
                        project: activeProject,
                        onContinue: {
                            if let onSelectProject = onSelectProject {
                                onSelectProject(activeProject)
                            }
                        }
                    )
                    .padding(.horizontal, AppSpacing.screenEdge)
                } else {
                    noActiveProjectCard
                        .padding(.horizontal, AppSpacing.screenEdge)
                }
                
                // Your Projects Section Header
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
                            Text("See All")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.assembleBrandPrimary)
                                .padding(.vertical, AppSpacing.xs)
                                .padding(.horizontal, AppSpacing.xs)
                                .contentShape(Rectangle())
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
                
                // Recent Activity Section
                if !viewModel.recentActivity.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Recent Activity")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, AppSpacing.screenEdge)
                        
                        VStack(spacing: AppSpacing.xs) {
                            ForEach(viewModel.recentActivity, id: \.id) { activity in
                                ActivityItemRow(activity: activity)
                                if activity.id != viewModel.recentActivity.last?.id {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                        .appCard()
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("AssembleAI")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
        .refreshable {
            await viewModel.loadContent()
        }
    }
    
    // MARK: - No Active Project Fallback Card
    
    private var noActiveProjectCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.assembleBrandPrimary)
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
