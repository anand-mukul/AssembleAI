//
//  ProjectCard.swift
//  AssembleAI
//

import SwiftUI

/// Premium, production-grade project card adhering to modern Apple HIG glassmorphic design.
struct ProjectCard: View {
    let project: AssemblyProject
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: AppSpacing.md) {
                // Category Symbol Icon Badge with Ambient Glow
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(categoryColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(categoryColor.opacity(0.2), lineWidth: 0.5)
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: project.imageName ?? "cpu.fill")
                        .font(.title3.weight(.medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(categoryColor)
                }
                
                // Content Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(project.title)
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer(minLength: 4)
                        
                        DifficultyBadge(difficulty: project.difficulty)
                    }
                    
                    Text(project.subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    
                    // Metadata Chips (Duration & Steps)
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(AppColors.tertiaryText)
                            Text("\(project.estimatedMinutes)m")
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(AppColors.tertiaryText)
                            Text("\(project.completedSteps)/\(project.totalSteps) steps")
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text(project.progressText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(project.isCompleted ? AppColors.success : categoryColor)
                    }
                    .padding(.top, 2)
                    
                    // Sleek Gradient Progress Track
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.tertiaryBackground)
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            project.isCompleted ? AppColors.success : .assembleBrandPrimary,
                                            project.isCompleted ? AppColors.success : categoryColor
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(project.progress))), height: 4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: project.progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
                
                // Trailing Chevron
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.tertiaryText.opacity(0.8))
                    .padding(.leading, 2)
            }
            .padding(AppSpacing.md)
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
        }
        .buttonStyle(ScaleButtonStyle(enableHaptic: false))
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
        case "woodworking", "furniture":
            return Color(red: 0.75, green: 0.55, blue: 0.35)
        default:
            return AppColors.badgeBlue
        }
    }
}

#Preview("Project Card") {
    VStack(spacing: 12) {
        ProjectCard(project: PreviewProjectFixture.previewProject, onTap: {})
    }
    .padding()
}
