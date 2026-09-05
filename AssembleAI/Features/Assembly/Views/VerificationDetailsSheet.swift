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
            // Drag handle
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Verification Details")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(stepTitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            VStack(spacing: AppSpacing.md) {
                detailTile(title: "EXPECTED STATE", value: result.expectedDescription, color: AppColors.success)
                detailTile(title: "OBSERVED STATE", value: result.detectedDescription, color: result.isCorrect ? AppColors.success : AppColors.error)
                detailTile(title: "EVIDENCE CONFIDENCE", value: "\(Int(result.confidence * 100))%", color: .assembleBrandPrimary)
                detailTile(title: "RESULT OUTCOME", value: result.status.rawValue.uppercased(), color: result.isCorrect ? AppColors.success : AppColors.error)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            
            Spacer()
            
            PrimaryButton(title: "Close") {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationCornerRadius(28)
    }
    
    private func detailTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
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
