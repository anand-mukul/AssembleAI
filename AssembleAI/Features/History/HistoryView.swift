//
//  HistoryView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

/// Production-ready History screen presenting real user assembly sessions, verification outcomes, and completion metrics.
struct HistoryView: View {
    @Query(sort: \LocalAssemblySession.startedAt, order: .reverse) private var sessions: [LocalAssemblySession]
    @Query private var localProjects: [LocalProject]
    @Environment(\.modelContext) private var modelContext
    
    var onSelectProject: ((AssemblyProject) -> Void)? = nil
    var onBrowseProjects: (() -> Void)? = nil
    
    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyHistoryView
            } else {
                sessionListView
            }
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Session List
    
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                // Header Summary Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completed Workflows")
                            .standardSectionHeader()
                        Text("\(sessions.count) Recorded Session\(sessions.count == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
                
                ForEach(sessions) { session in
                    sessionCard(session: session)
                        .padding(.horizontal, AppSpacing.screenEdge)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Session Card
    
    private func sessionCard(session: LocalAssemblySession) -> some View {
        let project = findProject(for: session.projectId)
        let isCompleted = session.statusRaw == SessionStatus.completed.rawValue
        let durationMinutes: Int = {
            if let end = session.completedAt {
                return max(1, Int(end.timeIntervalSince(session.startedAt) / 60))
            }
            return 1
        }()
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task {
                let repo = ProjectRepositoryFactory.resolve()
                let full = (try? await repo.fetchProject(byId: session.projectId)) ?? project
                if let full = full, let onSelectProject = onSelectProject {
                    onSelectProject(full)
                }
            }
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project?.title ?? "Physical Assembly Project")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "clock.fill")
                            .font(.caption2)
                        Text(isCompleted ? "Completed" : "In Progress")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(isCompleted ? AppColors.statusSuccess : AppColors.statusWarning)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((isCompleted ? AppColors.statusSuccess : AppColors.statusWarning).opacity(0.12))
                    )
                }
                
                Divider()
                
                HStack(spacing: AppSpacing.lg) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        Text("\(durationMinutes)m")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        Text("Step \(session.currentStepOrder)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    if let domain = project?.domain {
                        HStack(spacing: 4) {
                            Image(systemName: domain.iconName)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                            Text(domain.displayName)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            .appCard()
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Empty State
    
    private var emptyHistoryView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            
            AnimatedHeaderIcon(
                iconName: "clock.arrow.circlepath",
                iconSize: 32,
                circleDiameter: 68
            )
            
            VStack(spacing: AppSpacing.xs) {
                Text("No Assembly History Yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("When you start building and verifying physical hardware with your camera, your session history and accuracy metrics will appear here.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .adaptiveMultiline(alignment: .center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            if let onBrowseProjects = onBrowseProjects {
                PrimaryButton(title: "Explore Projects", iconName: "folder.fill") {
                    onBrowseProjects()
                }
                .frame(maxWidth: 220)
                .padding(.top, AppSpacing.xs)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenEdge)
    }
    
    private func findProject(for id: UUID) -> AssemblyProject? {
        if let bundled = BundledProjectRepository.bundledProjects.first(where: { $0.id == id }) {
            return bundled
        }
        if let local = localProjects.first(where: { $0.id == id }) {
            return AssemblyProject(
                id: local.id,
                title: local.title,
                subtitle: local.projectDescription,
                category: "Hardware",
                difficulty: Difficulty(rawValue: local.difficulty) ?? .beginner,
                estimatedMinutes: local.estimatedMinutes,
                totalSteps: 0,
                completedSteps: 0,
                imageName: local.thumbnailPath,
                isActive: false,
                nextAction: nil,
                description: local.projectDescription,
                components: [],
                steps: []
            )
        }
        return nil
    }
}

#Preview("History View Empty") {
    NavigationStack {
        HistoryView()
    }
}
