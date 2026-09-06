//
//  ActivityItemRow.swift
//  AssembleAI
//

import SwiftUI

/// Compact recent activity row item featuring semantic icon badge and clear hierarchy.
struct ActivityItemRow: View {
    let activity: ActivityItemModel
    
    var body: some View {
        HStack(spacing: AppSpacing.mdSm) {
            SemanticIconBadge(
                iconName: activity.iconName,
                size: 30,
                iconSize: 14,
                color: AppColors.badgeGreen
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed Step \(activity.stepOrder)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(activity.projectTitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(activity.timestampDescription)
                .font(.caption2)
                .foregroundColor(AppColors.tertiaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed step \(activity.stepOrder) of \(activity.projectTitle), \(activity.timestampDescription)")
    }
}

#Preview("Activity Item Row") {
    ActivityItemRow(
        activity: ActivityItemModel(
            stepOrder: 5,
            projectTitle: "LED Circuit",
            timestampDescription: "Today · 5:32 PM"
        )
    )
    .padding()
}
