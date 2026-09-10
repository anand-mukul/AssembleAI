//
//  ProjectsView.swift
//  AssembleAI
//

import SwiftUI

/// Main Projects screen featuring native SwiftUI search, category filtering, and project management.
@MainActor
struct ProjectsView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ProjectsViewModel()
    
    var onSelectProject: ((AssemblyProject) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment Filter Picker
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(ProjectFilterTab.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, AppSpacing.sm)
            
            // Projects Content
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
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
                                    await viewModel.loadProjects()
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
                    }
                    
                    if viewModel.filteredProjects.isEmpty {
                        emptyResultsOrProjectsState
                    } else {
                        ForEach(viewModel.filteredProjects, id: \.id) { project in
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
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, 100)
            }
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search projects or categories"
        )
        .onChange(of: viewModel.selectedFilter) {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .toolbar {
            if viewModel.isUserAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.showAddProjectSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.assembleBrandPrimary)
                            .touchTarget()
                    }
                    .accessibilityLabel("Add Project")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddProjectSheet) {
            AddProjectSheet(
                onChooseProject: {
                    viewModel.selectedFilter = .all
                }
            )
        }
        .onAppear {
            Task {
                await viewModel.loadProjects()
            }
        }
        .task {
            await viewModel.loadProjects()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssemblySessionUpdated"))) { _ in
            Task {
                await viewModel.loadProjects()
            }
        }
        .refreshable {
            await viewModel.loadProjects()
        }
    }
    
    // MARK: - Empty State View
    
    @ViewBuilder
    private var emptyResultsOrProjectsState: some View {
        if !viewModel.searchText.isEmpty {
            EmptyProjectsView(
                title: "No projects found",
                subtitle: "No assembly projects match \"\(viewModel.searchText)\". Try a different search.",
                iconName: "magnifyingglass",
                buttonTitle: nil,
                onAction: nil
            )
        } else if viewModel.selectedFilter != .all {
            EmptyProjectsView(
                title: "No \(viewModel.selectedFilter.rawValue) projects",
                subtitle: "There are currently no projects matching this status filter.",
                iconName: "folder.badge.minus",
                buttonTitle: "Show All Projects",
                onAction: {
                    viewModel.selectedFilter = .all
                }
            )
        } else {
            EmptyProjectsView(
                title: viewModel.isUserAdmin ? "No projects yet" : "No Published Projects",
                subtitle: viewModel.isUserAdmin
                    ? "Create your first assembly project to publish to the catalog."
                    : "Published hardware projects from the database will appear here.",
                iconName: "cube.box",
                buttonTitle: viewModel.isUserAdmin ? "Add Project" : nil,
                onAction: viewModel.isUserAdmin ? {
                    viewModel.showAddProjectSheet = true
                } : nil
            )
        }
    }
}

#Preview("Projects View") {
    NavigationStack {
        ProjectsView()
            .environmentObject(AppRouter())
    }
}
