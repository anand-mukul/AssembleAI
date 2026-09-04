//
//  StepsOverviewSheet.swift
//  AssembleAI
//

import SwiftUI

/// Elegant Apple-style modal sheet displaying the full assembly step timeline,
/// triggered by the top-right "(steps)" glass pill button.
struct StepsOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let currentStep: AssemblyStep
    let allSteps: [AssemblyStep]
    var onSelectStep: ((AssemblyStep) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Header progress summary
                    progressSummaryCard
                    
                    // Steps timeline list
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(allSteps) { step in
                            stepRow(for: step)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Assembly Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.assembleBrandPrimary)
                }
            }
        }
    }
    
    // MARK: - Progress Summary Card
    
    private var progressSummaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(AppColors.borderSubtle, lineWidth: 5)
                    .frame(width: 52, height: 52)
                
                let progress = Double(currentStep.stepOrder) / Double(max(1, allSteps.count))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.assembleBrandPrimary, .assembleActionAccent]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(currentStep.stepOrder) of \(allSteps.count)")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(currentStep.title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
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
    }
    
    // MARK: - Step Row
    
    private func stepRow(for step: AssemblyStep) -> some View {
        let isCurrent = step.id == currentStep.id
        let isCompleted = step.stepOrder < currentStep.stepOrder
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelectStep?(step)
            dismiss()
        }) {
            HStack(spacing: AppSpacing.mdSm) {
                // Status icon indicator
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Color.assembleBrandPrimary.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.assembleBrandPrimary)
                    } else if isCurrent {
                        Circle()
                            .fill(Color.assembleBrandPrimary)
                            .frame(width: 32, height: 32)
                        Text("\(step.stepOrder)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(AppColors.border, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        Text("\(step.stepOrder)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                // Step details
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(step.title)
                            .font(.subheadline.weight(isCurrent ? .semibold : .medium))
                            .foregroundColor(isCurrent ? AppColors.primaryText : (isCompleted ? AppColors.primaryText : AppColors.secondaryText))
                            .lineLimit(1)
                        
                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.assembleBrandPrimary))
                        }
                    }
                    
                    Text(step.instruction)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isCurrent ? Color.assembleBrandPrimary.opacity(0.08) : AppColors.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(isCurrent ? Color.assembleBrandPrimary.opacity(0.35) : AppColors.borderSubtle, lineWidth: isCurrent ? 1.0 : 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
