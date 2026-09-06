//
//  ActiveProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Prominent active assembly project card for the Home screen centerpiece adhering to Apple HIG standards.
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
                        .frame(width: 7, height: 7)
                    
                    Text("In Progress")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.statusLive.opacity(0.12))
                )
                
                Spacer()
                
                DifficultyBadge(difficulty: project.difficulty)
            }
            
            // Project Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.title3)
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
                        .monospacedDigit()
                        .foregroundColor(AppColors.secondaryText)
                }
                
                ProgressBar(
                    value: project.progress,
                    height: 6,
                    fillColor: .assembleBrandPrimary
                )
            }
            
            // Next Action Hint
            if let nextAction = project.nextAction, !nextAction.isEmpty {
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.assembleBrandPrimary)
                    
                    HStack(spacing: 4) {
                        Text("Next:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        Text(nextAction)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(AppColors.tertiaryBackground)
                )
            }
            
            // Primary Action CTA
            PrimaryButton(title: "Continue", iconName: "arrow.right") {
                onContinue()
            }
            .padding(.top, AppSpacing.xxs)
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
