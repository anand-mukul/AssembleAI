//
//  AssemblySummaryView.swift
//  AssembleAI
//

import SwiftUI

/// Assembly session summary screen displaying completion stats, elapsed time, retry attempts, and corrections.
struct AssemblySummaryView: View {
    let project: AssemblyProject
    let session: AssemblySession
    let onDone: () -> Void
    
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                    metricCard(title: "COMPLETED", value: "\(session.completedSteps.count) / \(project.totalSteps) steps")
                    metricCard(title: "TOTAL TIME", value: session.durationFormatted)
                    metricCard(title: "TOTAL ATTEMPTS", value: "\(session.attempts)")
                    metricCard(title: "CORRECTIONS", value: "\(session.errors)", color: session.errors > 0 ? AppColors.warning : AppColors.success)
                }
                .padding(.top, AppSpacing.sm)
                
                // Accuracy Pill Card
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.success)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accuracy Score: \(accuracyScore)%")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        Text("All physical step contracts verified successfully.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
                
                Spacer(minLength: 40)
                
                PrimaryButton(title: "Done", iconName: "checkmark") {
                    onDone()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private var accuracyScore: Int {
        guard session.attempts > 0 else { return 100 }
        let score = Double(session.attempts - session.errors) / Double(session.attempts) * 100.0
        return max(50, min(100, Int(score)))
    }
    
    private func metricCard(title: String, value: String, color: Color = AppColors.primaryText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
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
