//
//  VerificationDetailsSheet.swift
//  AssembleAI
//

import SwiftUI

/// Inspection sheet rendering physical state details for user review.
struct VerificationDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: VerificationResult
    let stepTitle: String
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Verification Details")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(stepTitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(spacing: AppSpacing.mdSm) {
                detailTile(title: "Expected State", value: result.expectedDescription, color: AppColors.success)
                detailTile(title: "Observed State", value: result.detectedDescription, color: result.isCorrect ? AppColors.success : AppColors.error)
                detailTile(title: "Evidence Confidence", value: "\(Int(result.confidence * 100))%", color: .assembleBrandPrimary)
                detailTile(title: "Result Outcome", value: result.status.rawValue.capitalized, color: result.isCorrect ? AppColors.success : AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer()
            
            PrimaryButton(title: "Close") {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
    
    private func detailTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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

#Preview("Verification Details Sheet") {
    VerificationDetailsSheet(
        result: VerificationResult(
            status: .correct,
            confidence: 0.94,
            detectedDescription: "220Ω Resistor placed in target slot",
            expectedDescription: "220Ω Resistor placed in target slot",
            explanation: "Verified"
        ),
        stepTitle: "Step 1: Place 220Ω Resistor"
    )
}
