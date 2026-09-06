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
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Dynamic Greeting Header
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(viewModel.greetingText)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                                .accessibilityAddTraits(.isHeader)
                            
                            Spacer()
                            
                            // Online / AI Ready Pill
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(AppColors.statusLive)
                                    .frame(width: 6, height: 6)
                                Text("Vision Ready")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                                    )
                            )
                        }
                        
                        Text("Ready for your next physical assembly task.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.top, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 8)
                    
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
                    .offset(y: hasAppeared ? 0 : 12)
                    
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
                                HStack(spacing: 4) {
                                    Text("See All")
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                }
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
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)
                    
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
                                            .opacity(0.3)
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .appCard()
                            .padding(.horizontal, AppSpacing.screenEdge)
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                    }
                }
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .navigationTitle("AssembleAI")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(reduceMotion ? .none : AppAnimation.entranceSpring) {
                hasAppeared = true
            }
        }
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
                GradientIconBadge(iconName: "wrench.and.screwdriver.fill", size: 36, iconSize: 16)
                
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
