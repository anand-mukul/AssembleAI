//
//  ActiveProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Prominent active assembly project card for the Home screen centerpiece.
struct ActiveProjectCard: View {
    let project: AssemblyProject
    let onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header Status & Difficulty
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.statusLive)
                        .frame(width: 6, height: 6)
                    Text("In Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                DifficultyBadge(difficulty: project.difficulty)
            }
            
            // Project Title & Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(project.subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(2)
            }
            
            // Progress Count & Percentage
            VStack(spacing: 6) {
                HStack {
                    Text("Step \(project.completedSteps + 1) of \(project.totalSteps)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Text(project.progressText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                ProgressBar(value: project.progress, height: 6)
            }
            
            // Next Action Hint
            if let nextAction = project.nextAction, !nextAction.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.assembleBrandPrimary)
                    
                    HStack(spacing: 2) {
                        Text("Next:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        Text(nextAction)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Primary Action CTA
            PrimaryButton(title: "Continue", iconName: "arrow.right") {
                onContinue()
            }
            .padding(.top, AppSpacing.xs)
        }
        .appCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.accessibilityLabelSummary)
        .accessibilityHint("Double tap to view project details and continue assembly.")
    }
}

#Preview("Active Project Card") {
    ActiveProjectCard(
        project: MockProjectData.sampleProjects[0],
        onContinue: {}
    )
    .padding()
}
