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
        .sensoryFeedback(.selection, trigger: viewModel.selectedFilter)
        .toolbar {
            if viewModel.isUserAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
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
    
    // MARK: - Empty State View (Apple HIG ContentUnavailableView)
    
    @ViewBuilder
    private var emptyResultsOrProjectsState: some View {
        if !viewModel.searchText.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
                .padding(.top, AppSpacing.xl)
        } else if viewModel.selectedFilter != .all {
            ContentUnavailableView {
                Label("No \(viewModel.selectedFilter.rawValue) Projects", systemImage: "folder.badge.minus")
            } description: {
                Text("There are currently no projects matching this status filter.")
            } actions: {
                Button("Show All Projects") {
                    viewModel.selectedFilter = .all
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, AppSpacing.xl)
        } else {
            ContentUnavailableView {
                Label(viewModel.isUserAdmin ? "No Projects Yet" : "No Published Projects", systemImage: "cube.box")
            } description: {
                Text(viewModel.isUserAdmin
                    ? "Create your first assembly project to publish to the catalog."
                    : "Published hardware projects from the database will appear here.")
            } actions: {
                if viewModel.isUserAdmin {
                    Button("Add Project") {
                        viewModel.showAddProjectSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.assembleBrandPrimary)
                }
            }
            .padding(.top, AppSpacing.xl)
        }
    }
}

#Preview("Projects View") {
    NavigationStack {
        ProjectsView()
            .environmentObject(AppRouter())
    }
}
