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
                
                // Upfront Progress Tracker (In Front)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: project.isCompleted ? "checkmark.seal.fill" : (project.completedSteps > 0 ? "bolt.fill" : "play.circle.fill"))
                                .foregroundColor(project.isCompleted ? AppColors.success : .assembleBrandPrimary)
                                .font(.subheadline)
                            
                            Text(project.isCompleted ? "Assembly Completed" : (project.completedSteps > 0 ? "In Progress" : "Ready to Assemble"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        Spacer()
                        
                        Text("\(project.completedSteps) of \(project.totalSteps) steps (\(project.progressText))")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    ProgressBar(
                        value: project.progress,
                        height: 6,
                        fillColor: project.isCompleted ? AppColors.success : .assembleBrandPrimary
                    )
                    
                    if let next = project.nextAction, !project.isCompleted, !next.isEmpty {
                        HStack(spacing: 4) {
                            Text("Next:")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.assembleBrandPrimary)
                            Text(next)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }
                .appCard()
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
                        .padding(.bottom, AppSpacing.md)
                    }
                }
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
            // Ambient Progress Bar Track spanning top of dock
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.tertiaryText.opacity(0.18))
                    
                    Rectangle()
                        .fill(project.isCompleted ? AppColors.success : Color.assembleBrandPrimary)
                        .frame(width: max(0, proxy.size.width * CGFloat(project.progress)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: project.progress)
                }
            }
            .frame(height: 3)
            
            HStack(spacing: AppSpacing.md) {
                // Circular Progress Ring + Status Info
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .stroke(AppColors.tertiaryText.opacity(0.2), lineWidth: 3)
                            .frame(width: 34, height: 34)
                        
                        Circle()
                            .trim(from: 0, to: max(0.02, CGFloat(project.progress)))
                            .stroke(
                                project.isCompleted ? AppColors.success : Color.assembleBrandPrimary,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 34, height: 34)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: project.progress)
                        
                        if project.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.success)
                        } else {
                            Text("\(Int(project.progress * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dockTitle)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Text(dockSubtitle)
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 8)
                
                // Primary Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStartAssembly?(project)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: ctaButtonIcon)
                            .font(.system(size: 14, weight: .bold))
                        Text(ctaButtonTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColors.premiumButtonForeground)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 46)
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
