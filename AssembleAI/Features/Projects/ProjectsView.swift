//
//  ProjectsView.swift
//  AssembleAI
//

import SwiftUI

/// Main Projects screen featuring native SwiftUI search, category filtering, and project management.
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
            .background(AppColors.appBackground)
            
            // Projects Content
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
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
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search projects or categories"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    viewModel.showAddProjectSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Add Project")
            }
        }
        .sheet(isPresented: $viewModel.showAddProjectSheet) {
            AddProjectSheet(
                onChooseProject: {
                    viewModel.selectedFilter = .all
                }
            )
        }
        .task {
            await viewModel.loadProjects()
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
                title: "No projects yet",
                subtitle: "Start your first assembly project and we'll guide you step by step.",
                iconName: "folder.badge.plus",
                buttonTitle: "Add Project",
                onAction: {
                    viewModel.showAddProjectSheet = true
                }
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
