//
//  ExpectedVsObservedView.swift
//  AssembleAI
//

import SwiftUI

/// Visual diagram comparing expected physical placement vs observed mistake.
struct ExpectedVsObservedView: View {
    let expectedText: String
    let observedText: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Expected Column
            VStack(spacing: AppSpacing.xs) {
                Text("EXPECTED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.success)
                    .tracking(1.0)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.success.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppColors.success.opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.success)
                        Text(expectedText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    .padding(AppSpacing.xs)
                }
                .frame(height: 90)
            }
            .frame(maxWidth: .infinity)
            
            // Divider Icon
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
            
            // Observed Column
            VStack(spacing: AppSpacing.xs) {
                Text("OBSERVED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.error)
                    .tracking(1.0)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.error.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppColors.error.opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundColor(AppColors.error)
                        Text(observedText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    .padding(AppSpacing.xs)
                }
                .frame(height: 90)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Expected: \(expectedText). Observed: \(observedText).")
    }
}

#Preview("Expected vs Observed View") {
    ExpectedVsObservedView(
        expectedText: "Row 10 → Row 15",
        observedText: "Row 10 → Row 14"
    )
    .padding()
}
