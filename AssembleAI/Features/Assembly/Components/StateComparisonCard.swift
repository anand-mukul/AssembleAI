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
                    Text("Expected State")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.success)
                    
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
                    Text("Observed State")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(issueType != nil ? AppColors.error : AppColors.secondaryText)
                    
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
                    
                    Text("Issue:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(issueTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                    
                    Spacer()
                    
                    BadgeView(text: issueType.rawValue.capitalized, color: AppColors.badgeOrange)
                }
            }
        }
        .appCard()
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
