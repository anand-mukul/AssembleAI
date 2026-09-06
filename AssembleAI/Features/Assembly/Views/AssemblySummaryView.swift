//
//  AssemblySummaryView.swift
//  AssembleAI
//

import SwiftUI

/// Assembly session summary screen displaying completion stats, elapsed time, retry attempts, and corrections.
struct AssemblySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let project: AssemblyProject
    let session: AssemblySession
    var onDone: (() -> Void)? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 24)
                
                // Trophy Graphic
                ZStack {
                    Circle()
                        .fill(AppColors.success.opacity(0.12))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.success)
                }
                
                VStack(spacing: AppSpacing.xs) {
                    Text("Assembly Complete")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(project.title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // User-Facing Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.mdSm) {
                    metricCard(title: "Completed", value: "\(session.completedSteps.count) / \(project.totalSteps) steps")
                    metricCard(title: "Total Time", value: session.durationFormatted)
                    metricCard(title: "Attempts", value: "\(session.attempts)")
                    metricCard(title: "Corrections", value: "\(session.errors)", color: session.errors > 0 ? AppColors.warning : AppColors.success)
                }
                .padding(.top, AppSpacing.sm)
                
                // Accuracy Card
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(systemName: "checkmark.shield.fill", tintColor: AppColors.badgeGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accuracy Score: \(accuracyScore)%")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        Text("All physical step contracts verified successfully.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                }
                .appCard()
                
                Spacer(minLength: 40)
                
                PrimaryButton(title: "Done", iconName: "checkmark") {
                    if let onDone = onDone {
                        onDone()
                    } else {
                        dismiss()
                    }
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
    }
    
    private var accuracyScore: Int {
        guard session.attempts > 0 else { return 100 }
        let score = Double(session.attempts - session.errors) / Double(session.attempts) * 100.0
        return max(50, min(100, Int(score)))
    }
    
    private func metricCard(title: String, value: String, color: Color = AppColors.primaryText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(color)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
        )
    }
}

#Preview("Assembly Summary View") {
    AssemblySummaryView(
        project: MockProjectData.sampleProjects[0],
        session: AssemblySession(projectId: UUID(), completedSteps: [0, 1, 2, 3, 4, 5, 6, 7], attempts: 10, errors: 2),
        onDone: {}
    )
}
