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
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(Color.assembleBrandPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: project.imageName ?? "cpu")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(project.title)
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        DifficultyBadge(difficulty: project.difficulty)
                    }
                    
                    Text(project.subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text("~\(project.estimatedMinutes) min • \(project.completedSteps)/\(project.totalSteps) steps")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Spacer()
                        
                        Text(project.progressText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(project.isCompleted ? AppColors.success : AppColors.secondaryText)
                    }
                    .padding(.top, 2)
                    
                    ProgressBar(
                        value: project.progress,
                        height: 3,
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
