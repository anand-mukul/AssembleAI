//
//  ActivityItemRow.swift
//  AssembleAI
//

import SwiftUI

/// Compact recent activity row item featuring unified gradient icon badge and clear hierarchy.
struct ActivityItemRow: View {
    let activity: ActivityItemModel
    
    var body: some View {
        HStack(spacing: AppSpacing.mdSm) {
            GradientIconBadge(
                iconName: activity.iconName,
                size: 34,
                iconSize: 14,
                colors: [AppColors.success, AppColors.success.opacity(0.75)]
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
        .padding(.vertical, 4)
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
