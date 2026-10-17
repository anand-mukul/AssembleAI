//
//  ActiveProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Prominent active assembly project centerpiece for the Home screen adhering to Apple HIG glassmorphic standards.
struct ActiveProjectCard: View {
    let project: AssemblyProject
    let onContinue: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header Status & Difficulty
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.statusLive)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.15 : 0.85)
                        .opacity(isPulsing ? 1.0 : 0.6)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                    
                    Text("In Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AppColors.statusLive.opacity(0.12))
                        .overlay(
                            Capsule()
                                .strokeBorder(AppColors.statusLive.opacity(0.25), lineWidth: 0.5)
                        )
                )
                
                Spacer()
                
                DifficultyBadge(difficulty: project.difficulty)
            }
            
            // Project Title & Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.title3.weight(.bold))
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
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Text(project.progressText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(.assembleBrandPrimary)
                }
                
                // Sleek Dual-Gradient Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.tertiaryBackground)
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .assembleBrandPrimary,
                                        Color.assembleBrandPrimary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(project.progress))), height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: project.progress)
                    }
                }
                .frame(height: 6)
            }
            
            // Next Action Hint
            if let nextAction = project.nextAction, !nextAction.isEmpty {
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.assembleBrandPrimary)
                    
                    HStack(spacing: 4) {
                        Text("Next:")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.primaryText)
                        Text(nextAction)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(AppColors.tertiaryBackground.opacity(0.8))
                )
            }
            
            // Primary Action CTA
            PrimaryButton(title: "Continue Assembly", iconName: "arrow.right") {
                onContinue()
            }
            .padding(.top, AppSpacing.xxs)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .shadow(color: AppShadow.subtleColor, radius: 4, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .onAppear {
            isPulsing = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.accessibilityLabelSummary)
        .accessibilityHint("Double tap to view project details and continue assembly.")
    }
}

#Preview("Active Project Card") {
    ActiveProjectCard(
        project: PreviewProjectFixture.previewProject,
        onContinue: {}
    )
    .padding()
}
