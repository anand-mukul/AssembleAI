//
//  ActivityItemRow.swift
//  AssembleAI
//

import SwiftUI

/// Compact recent activity row item.
struct ActivityItemRow: View {
    let activity: ActivityItemModel
    
    var body: some View {
        HStack(spacing: AppSpacing.mdSm) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: activity.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.success)
            }
            
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
