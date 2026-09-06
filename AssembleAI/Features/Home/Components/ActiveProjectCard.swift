//
//  ActiveProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Prominent active assembly project card for the Home screen centerpiece with Silicon Valley glassmorphism.
struct ActiveProjectCard: View {
    let project: AssemblyProject
    let onContinue: () -> Void
    
    @State private var livePulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header Status & Difficulty
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.statusLive)
                        .frame(width: 8, height: 8)
                        .scaleEffect(livePulse ? 1.25 : 1.0)
                        .opacity(livePulse ? 1.0 : 0.7)
                    
                    Text("In Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.statusLive.opacity(0.12))
                )
                
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                ProgressBar(
                    value: project.progress,
                    height: 6,
                    gradientColors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd]
                )
            }
            
            // Next Action Hint
            if let nextAction = project.nextAction, !nextAction.isEmpty {
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.assembleBrandPrimary)
                    
                    HStack(spacing: 3) {
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.tertiaryBackground.opacity(0.6))
                )
            }
            
            // Primary Action CTA
            PrimaryButton(title: "Continue", iconName: "arrow.right") {
                onContinue()
            }
            .padding(.top, AppSpacing.xxs)
        }
        .appCard()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
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
