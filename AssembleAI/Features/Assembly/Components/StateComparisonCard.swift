//
//  StateComparisonCard.swift
//  AssembleAI
//

import SwiftUI

/// Reusable research & development card rendering expected state vs observed state and identified issue type.
struct StateComparisonCard: View {
    let expectedText: String
    let observedText: String
    let issueTitle: String?
    let issueType: StateIssueType?
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                // Expected Column
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPECTED STATE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.success)
                        .tracking(1.0)
                    
                    Text(expectedText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                // Observed Column
                VStack(alignment: .leading, spacing: 4) {
                    Text("OBSERVED STATE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(issueType != nil ? AppColors.error : AppColors.secondaryText)
                        .tracking(1.0)
                    
                    Text(observedText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let issueTitle = issueTitle, let issueType = issueType {
                Divider()
                
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.error)
                    
                    Text("ISSUE:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    Text(issueTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                    
                    Spacer()
                    
                    BadgeView(text: issueType.rawValue.uppercased(), color: AppColors.error)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.border.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("State Comparison Card") {
    StateComparisonCard(
        expectedText: "220Ω Resistor (Row 10 → Row 15)",
        observedText: "220Ω Resistor (Row 10 → Row 14)",
        issueTitle: "Wrong position",
        issueType: .wrongPosition
    )
    .padding()
}
