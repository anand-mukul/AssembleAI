//
//  StepRowView.swift
//  AssembleAI
//

import SwiftUI

/// Apple HIG-compliant list row representing a single guided assembly step in the project details.
struct StepRowView: View {
    let step: ProjectStepSummary
    let isCompleted: Bool
    
    init(step: ProjectStepSummary, isCompleted: Bool = false) {
        self.step = step
        self.isCompleted = isCompleted
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Step Number / Completion Status Badge
            ZStack {
                Circle()
                    .fill(isCompleted ? AppColors.success : AppColors.secondaryGroupedBackground)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isCompleted ? AppColors.success : AppColors.brandPrimary.opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step.stepOrder)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                }
            }
            .padding(.top, 2)
            
            // Step Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: AppSpacing.xs) {
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Duration Tag
                    Label("~\(step.expectedDurationMinutes) min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                if !step.instruction.isEmpty {
                    Text(step.instruction)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                        .adaptiveMultiline()
                }
                
                // Metadata Chips
                HStack(spacing: AppSpacing.xs) {
                    if step.visualContract != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Camera Verified")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.assembleBrandPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.assembleBrandPrimary.opacity(0.12))
                        )
                    }
                    
                    if !step.commonMistakes.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.shield")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(step.commonMistakes.count) guidance tips")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(AppColors.badgeOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppColors.badgeOrange.opacity(0.12))
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.stepOrder): \(step.title). \(isCompleted ? "Completed." : "")")
    }
}

#Preview {
    VStack(spacing: 12) {
        StepRowView(
            step: ProjectStepSummary(
                stepOrder: 1,
                title: "Insert 220Ω Resistor",
                instruction: "Place current limiting resistor across pins 10E and 15F.",
                expectedDurationMinutes: 2,
                visualContract: VisualContract(),
                commonMistakes: []
            ),
            isCompleted: true
        )
        
        StepRowView(
            step: ProjectStepSummary(
                stepOrder: 2,
                title: "Insert 100µF Capacitor",
                instruction: "Observe polarity. The white stripe faces the ground rail.",
                expectedDurationMinutes: 3,
                visualContract: VisualContract(),
                commonMistakes: []
            ),
            isCompleted: false
        )
    }
    .padding()
    .background(AppColors.groupedBackground)
}
