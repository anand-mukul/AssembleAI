//
//  HistoryView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

/// Production-ready History screen presenting real user assembly sessions, verification outcomes, and completion metrics.
struct HistoryView: View {
    @Query(sort: \LocalAssemblySession.startedAt, order: .reverse) private var sessions: [LocalAssemblySession]
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
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Session List
    
    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Header Summary Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COMPLETED WORKFLOWS")
                            .sectionHeaderStyle()
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
                
                Spacer(minLength: 32)
            }
            .padding(.top, AppSpacing.xs)
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
        
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project?.title ?? "Hardware Assembly Project")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                    Text(isCompleted ? "Completed" : "In Progress")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isCompleted ? AppColors.statusSuccess : AppColors.statusWarning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isCompleted ? AppColors.statusSuccess : AppColors.statusWarning).opacity(0.12))
                .clipShape(Capsule())
            }
            
            Divider().opacity(0.3)
            
            HStack(spacing: AppSpacing.lg) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                    Text("\(durationMinutes)m")
                        .font(.caption)
                        .fontWeight(.medium)
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
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        Text(domain.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
            }
        }
        .appCard()
    }
    
    // MARK: - Empty State
    
    private var emptyHistoryView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.assembleBrandPrimary)
            }
            
            VStack(spacing: AppSpacing.xs) {
                Text("No Assembly History Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("When you start building and verifying physical hardware with your camera, your session history and accuracy metrics will appear here.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if let onBrowseProjects = onBrowseProjects {
                PrimaryButton(title: "Explore Projects", iconName: "folder.fill") {
                    onBrowseProjects()
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.sm)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenEdge)
    }
    
    private func findProject(for id: UUID) -> AssemblyProject? {
        BundledProjectRepository.bundledProjects.first { $0.id == id }
            ?? SampleProjectData.sampleProjects.first { $0.id == id }
    }
}

#Preview("History View Empty") {
    NavigationStack {
        HistoryView()
    }
}
