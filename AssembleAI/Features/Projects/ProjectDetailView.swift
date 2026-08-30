//
//  ProjectDetailView.swift
//  AssembleAI
//

import SwiftUI

/// Detailed assembly project view introducing hardware requirements, step progress, and assembly launch CTAs.
struct ProjectDetailView: View {
    @EnvironmentObject private var router: AppRouter
    let project: AssemblyProject
    
    var onStartAssembly: ((AssemblyProject) -> Void)? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Technical Vector Visual Card
                ProjectVisualCard(
                    category: project.category,
                    iconName: project.imageName,
                    height: 160
                )
                .padding(.horizontal, AppSpacing.screenEdge)
                
                // Metadata Header
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        DifficultyBadge(difficulty: project.difficulty)
                        
                        Spacer()
                        
                        HStack(spacing: AppSpacing.md) {
                            Label("\(project.totalSteps) steps", systemImage: "list.bullet")
                            Label("~\(project.estimatedMinutes) min", systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Text(project.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(project.subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                
                // About Description
                if !project.description.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("About")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(project.description)
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                }
                
                // You'll Need (Components List)
                if !project.components.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("You'll need")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, AppSpacing.screenEdge)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(project.components.enumerated()), id: \.element.id) { index, comp in
                                ComponentRequirementRow(component: comp)
                                    .padding(.horizontal, AppSpacing.md)
                                
                                if index < project.components.count - 1 {
                                    Divider()
                                        .padding(.leading, 32)
                                }
                            }
                        }
                        .appCard(padding: AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                }
                
                // Progress Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Text("\(project.completedSteps) of \(project.totalSteps) steps")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    ProgressBar(
                        value: project.progress,
                        height: 8,
                        fillColor: project.isCompleted ? AppColors.success : Color.assembleBrandPrimary
                    )
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                
                // Primary Action Button
                PrimaryButton(
                    title: ctaButtonTitle,
                    iconName: ctaButtonIcon
                ) {
                    if let onStartAssembly = onStartAssembly {
                        onStartAssembly(project)
                    }
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.xxl)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - CTA Helpers
    
    private var ctaButtonTitle: String {
        if project.isCompleted {
            return "Review Assembly"
        } else if project.completedSteps > 0 {
            return "Continue Assembly"
        } else {
            return "Start Assembly"
        }
    }
    
    private var ctaButtonIcon: String {
        if project.isCompleted {
            return "checkmark.circle.fill"
        } else if project.completedSteps > 0 {
            return "arrow.right"
        } else {
            return "play.fill"
        }
    }
}

#Preview("Project Detail View - In Progress") {
    NavigationStack {
        ProjectDetailView(project: MockProjectData.sampleProjects[0])
            .environmentObject(AppRouter())
    }
}

#Preview("Project Detail View - Not Started") {
    NavigationStack {
        ProjectDetailView(project: MockProjectData.sampleProjects[1])
            .environmentObject(AppRouter())
    }
}
