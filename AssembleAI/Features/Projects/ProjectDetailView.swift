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
                        .adaptiveMultiline()
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                
                // About Description
                if !project.description.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("About")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(project.description)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                            .lineSpacing(3)
                            .adaptiveMultiline()
                    }
                    .appCard()
                    .padding(.horizontal, AppSpacing.screenEdge)
                }
                
                // You'll Need (Components List)
                if !project.components.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("You'll need")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, AppSpacing.screenEdge)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(project.components.enumerated()), id: \.element.id) { index, comp in
                                ComponentRequirementRow(component: comp)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                
                                if index < project.components.count - 1 {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                        .appCard(padding: 0)
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                }
                
                // Assembly Steps Section
                if !project.steps.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Assembly Steps")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                            
                            Text("\(project.steps.count) steps")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.horizontal, AppSpacing.screenEdge)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(project.steps.enumerated()), id: \.element.id) { index, step in
                                let isStepDone = index < project.completedSteps
                                StepRowView(step: step, isCompleted: isStepDone)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.xs)
                                
                                if index < project.steps.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .appCard(padding: 0)
                        .padding(.horizontal, AppSpacing.screenEdge)
                    }
                }
                
                // Progress Section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text("Progress")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Text("\(project.completedSteps) of \(project.totalSteps) steps")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    ProgressBar(
                        value: project.progress,
                        height: 8,
                        fillColor: project.isCompleted ? AppColors.success : .assembleBrandPrimary
                    )
                }
                .appCard()
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.md)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            bottomActionDock
        }
    }
    
    // MARK: - Fixed Bottom Action Dock
    
    private var bottomActionDock: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                // Step Progress & Estimation Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(dockTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    
                    Text(dockSubtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 12)
                
                // Primary Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStartAssembly?(project)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: ctaButtonIcon)
                            .font(.system(size: 15, weight: .bold))
                        Text(ctaButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppColors.premiumButtonForeground)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(height: 50)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.premiumButtonBackground)
                            .shadow(color: Color.assembleBrandPrimary.opacity(0.35), radius: 8, x: 0, y: 3)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .touchTarget()
                .accessibilityLabel("\(ctaButtonTitle). \(dockTitle), \(dockSubtitle)")
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }
    
    private var dockTitle: String {
        if project.isCompleted {
            return "Assembly Complete"
        } else if project.completedSteps > 0 {
            return "Step \(project.completedSteps + 1) of \(project.totalSteps)"
        } else {
            return "\(project.totalSteps) Guided Steps"
        }
    }
    
    private var dockSubtitle: String {
        if project.isCompleted {
            return "All verification steps passed"
        } else {
            return "~\(project.estimatedMinutes) min · \(project.difficulty.rawValue)"
        }
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
        ProjectDetailView(project: MockProjectData.previewProject)
            .environmentObject(AppRouter())
    }
}
