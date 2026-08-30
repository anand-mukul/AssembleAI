//
//  ProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Clean, modular project card component for Home and Projects screens.
struct ProjectCard: View {
    let project: AssemblyProject
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: AppSpacing.md) {
                // Category Symbol Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: project.imageName ?? "cpu")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(project.title)
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        DifficultyBadge(difficulty: project.difficulty)
                    }
                    
                    Text(project.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: AppSpacing.md) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("~\(project.estimatedMinutes) min")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.tertiaryText)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                            Text("\(project.completedSteps)/\(project.totalSteps) steps")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.tertiaryText)
                        
                        Spacer()
                        
                        Text(project.progressText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(project.isCompleted ? AppColors.success : AppColors.secondaryText)
                    }
                    .padding(.top, 2)
                    
                    ProgressBar(
                        value: project.progress,
                        height: 4,
                        fillColor: project.isCompleted ? AppColors.success : Color.assembleBrandPrimary
                    )
                    .padding(.top, 2)
                }
            }
            .appCard()
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.accessibilityLabelSummary)
        .accessibilityHint("Double tap to open project details.")
    }
}

#Preview("Project Card") {
    VStack(spacing: 12) {
        ProjectCard(project: MockProjectData.sampleProjects[0], onTap: {})
        ProjectCard(project: MockProjectData.sampleProjects[3], onTap: {})
    }
    .padding()
}
