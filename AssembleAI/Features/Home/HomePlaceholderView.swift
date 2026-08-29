//
//  HomePlaceholderView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

/// Main application home screen demonstrating local-first SwiftData persistence and Supabase synchronization status.
struct HomePlaceholderView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.modelContext) private var modelContext
    
    @State private var projects: [Project] = []
    @State private var isCreatingProject: Bool = false
    @State private var newProjectTitle: String = ""
    @State private var newProjectDescription: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authService.currentUser {
                    Section {
                        UserSummaryRow(user: user)
                    }
                }
                
                Section {
                    if projects.isEmpty {
                        ContentUnavailableView {
                            Label("No Projects", systemImage: "square.stack.3d.up.slash")
                        } description: {
                            Text("Create a local assembly workflow to start tracking instructions, timing, and sync state.")
                        } actions: {
                            Button("New Project") {
                                isCreatingProject = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: AppSpacing.lg, leading: AppSpacing.md, bottom: AppSpacing.lg, trailing: AppSpacing.md))
                    } else {
                        ForEach(projects) { project in
                            ProjectRow(project: project)
                        }
                    }
                } header: {
                    Text("Projects")
                } footer: {
                    Text("Projects are stored locally first and marked for upload when cloud sync is available.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Workspace")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            Task {
                                await authService.signOut()
                                router.transitionToWelcome()
                            }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .task {
                await loadLocalProjects()
            }
            .refreshable {
                await loadLocalProjects()
            }
            .sheet(isPresented: $isCreatingProject) {
                createProjectSheet
            }
        }
    }
    
    @ViewBuilder
    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Title", text: $newProjectTitle)
                        .textInputAutocapitalization(.words)
                    TextField("Description", text: $newProjectDescription, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetProjectDraft()
                        isCreatingProject = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNewProject()
                        isCreatingProject = false
                    }
                    .disabled(newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func loadLocalProjects() async {
        let repository = LocalFirstProjectRepository(modelContext: modelContext)
        if let loaded = try? await repository.fetchProjects() {
            projects = loaded
        }
    }
    
    private func createNewProject() {
        let repository = LocalFirstProjectRepository(modelContext: modelContext)
        let ownerId = UUID(uuidString: authService.currentUser?.id ?? "") ?? UUID()
        
        let newProject = Project(
            ownerId: ownerId,
            title: newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: "Intermediate",
            estimatedMinutes: 45,
            syncState: .pendingUpload
        )
        
        Task {
            try? await repository.saveProject(newProject)
            await loadLocalProjects()
            resetProjectDraft()
        }
    }
    
    private func resetProjectDraft() {
        newProjectTitle = ""
        newProjectDescription = ""
    }
}

private struct UserSummaryRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: user.isGuest ? "person.crop.circle.badge.clock" : "person.crop.circle.badge.checkmark")
                .font(.title2)
                .foregroundColor(user.isGuest ? AppColors.warning : .assembleBrandPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill((user.isGuest ? AppColors.warning : Color.assembleBrandPrimary).opacity(0.12))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(user.isGuest ? "Local-only session" : "Cloud sync enabled")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer(minLength: AppSpacing.sm)
            
            BadgeView(
                text: user.isGuest ? "Local" : "Synced",
                color: user.isGuest ? AppColors.warning : AppColors.success
            )
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "shippingbox")
                .font(.headline)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.assembleBrandPrimary.opacity(0.12))
                )
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)
                    Spacer(minLength: AppSpacing.sm)
                    BadgeView(text: project.difficulty, color: .indigo)
                }
                
                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                }
                
                HStack(spacing: AppSpacing.md) {
                    Label("\(project.estimatedMinutes) min", systemImage: "clock")
                    Label(syncLabel, systemImage: syncIconName)
                        .foregroundColor(syncColor)
                }
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private var syncLabel: String {
        switch project.syncState {
        case .synced:
            return "Synced"
        case .pendingUpload:
            return "Pending Upload"
        case .pendingDelete:
            return "Pending Delete"
        case .conflict:
            return "Conflict"
        }
    }
    
    private var syncIconName: String {
        project.syncState == .synced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    private var syncColor: Color {
        project.syncState == .synced ? AppColors.success : AppColors.warning
    }
}

#Preview("Home View") {
    HomePlaceholderView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
        .modelContainer(PersistenceController.preview.container)
}
