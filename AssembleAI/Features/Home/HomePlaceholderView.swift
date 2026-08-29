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
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Session Header Card
                    if let user = authService.currentUser {
                        VStack(spacing: AppSpacing.xs) {
                            HStack {
                                Image(systemName: user.isGuest ? "person.crop.circle.badge.clock" : "shield.checkmark.fill")
                                    .foregroundColor(user.isGuest ? AppColors.warning : AppColors.brandPrimary)
                                Text(user.isGuest ? "Guest Mode (Local Only)" : "Supabase Active")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(user.isGuest ? Color.orange : Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(user.isGuest ? "Local Storage" : "Cloud Synced")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Welcome back,")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    Text(user.displayName)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primaryText)
                                }
                                Spacer()
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.secondaryGroupedBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppColors.border, lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    // Projects Section Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Assembly Projects")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                            Text("Local SwiftData • Free Supabase Storage")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                        
                        Button(action: {
                            isCreatingProject = true
                        }) {
                            Label("New Project", systemImage: "plus")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.brandPrimary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Projects List / Grid
                    if projects.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppColors.tertiaryText)
                            Text("No projects yet")
                                .font(.headline)
                                .foregroundColor(AppColors.secondaryText)
                            Text("Tap 'New Project' to create your first local assembly workflow.")
                                .font(.caption)
                                .foregroundColor(AppColors.tertiaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(AppSpacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.secondaryBackground)
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    } else {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(projects, id: \.id) { project in
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        HStack {
                                            Text(project.title)
                                                .font(.headline)
                                                .foregroundColor(AppColors.primaryText)
                                            Spacer()
                                            BadgeView(text: project.difficulty, color: .indigo)
                                        }
                                        
                                        if !project.description.isEmpty {
                                            Text(project.description)
                                                .font(.subheadline)
                                                .foregroundColor(AppColors.secondaryText)
                                                .lineLimit(2)
                                        }
                                        
                                        HStack(spacing: AppSpacing.md) {
                                            Label("\(project.estimatedMinutes) mins", systemImage: "clock")
                                            Label(project.syncState.rawValue, systemImage: project.syncState == .synced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                                .foregroundColor(project.syncState == .synced ? AppColors.success : AppColors.warning)
                                        }
                                        .font(.caption)
                                        .foregroundColor(AppColors.tertiaryText)
                                    }
                                }
                                .padding(AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppColors.secondaryGroupedBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(AppColors.border, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    Spacer(minLength: AppSpacing.xl)
                    
                    // Sign Out Button
                    SecondaryButton(title: "Sign Out", iconName: "rectangle.portrait.and.arrow.right") {
                        Task {
                            await authService.signOut()
                            router.transitionToWelcome()
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationTitle("AssembleAI Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadLocalProjects)
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
                    TextField("Description", text: $newProjectDescription)
                }
            }
            .navigationTitle("New Assembly Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCreatingProject = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNewProject()
                        isCreatingProject = false
                    }
                    .disabled(newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func loadLocalProjects() {
        let repository = LocalFirstProjectRepository(modelContext: modelContext)
        Task {
            if let loaded = try? await repository.fetchProjects() {
                self.projects = loaded
            }
        }
    }
    
    private func createNewProject() {
        let repository = LocalFirstProjectRepository(modelContext: modelContext)
        let ownerId = UUID(uuidString: authService.currentUser?.id ?? "") ?? UUID()
        
        let newProject = Project(
            ownerId: ownerId,
            title: newProjectTitle,
            description: newProjectDescription,
            difficulty: "Intermediate",
            estimatedMinutes: 45,
            syncState: .pendingUpload
        )
        
        Task {
            try? await repository.saveProject(newProject)
            loadLocalProjects()
            newProjectTitle = ""
            newProjectDescription = ""
        }
    }
}

#Preview("Home View") {
    HomePlaceholderView()
        .environmentObject(AppRouter())
        .environmentObject(SupabaseAuthService())
}
