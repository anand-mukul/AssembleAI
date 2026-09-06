//
//  ProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Clean, modular project card component for Home and Projects screens adhering to Apple HIG.
struct ProjectCard: View {
    let project: AssemblyProject
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: AppSpacing.md) {
                // Category Symbol Icon Badge
                SemanticIconBadge(
                    iconName: project.imageName ?? "cpu",
                    size: 44,
                    iconSize: 20,
                    color: categoryColor
                )
                
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
                            .monospacedDigit()
                            .foregroundColor(project.isCompleted ? AppColors.success : AppColors.secondaryText)
                    }
                    .padding(.top, 2)
                    
                    ProgressBar(
                        value: project.progress,
                        height: 4,
                        fillColor: project.isCompleted ? AppColors.success : .assembleBrandPrimary
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
    
    private var categoryColor: Color {
        switch project.category.lowercased() {
        case "robotics":
            return AppColors.badgeOrange
        case "iot", "smart home":
            return AppColors.badgePurple
        case "audio":
            return AppColors.badgeIndigo
        case "wearables":
            return AppColors.badgeTeal
        default:
            return AppColors.badgeBlue
        }
    }
}

#Preview("Project Card") {
    VStack(spacing: 12) {
        ProjectCard(project: MockProjectData.sampleProjects[0], onTap: {})
        ProjectCard(project: MockProjectData.sampleProjects[3], onTap: {})
    }
    .padding()
}
