//
//  ComponentRequirementRow.swift
//  AssembleAI
//

import SwiftUI

/// Clean requirement item row for Project Details screen with unified badges.
struct ComponentRequirementRow: View {
    let component: ComponentRequirement
    
    var body: some View {
        HStack(spacing: AppSpacing.mdSm) {
            ZStack {
                Circle()
                    .fill(component.isRequired ? AppColors.iconBadgeGradientStart.opacity(0.15) : AppColors.tertiaryBackground)
                    .frame(width: 24, height: 24)
                
                Image(systemName: component.isRequired ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(component.isRequired ? .assembleBrandPrimary : AppColors.secondaryText)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                if !component.detail.isEmpty {
                    Text(component.detail)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
            
            Text(component.isRequired ? "Required" : "Optional")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(component.isRequired ? AppColors.primaryText : AppColors.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(component.isRequired ? AppColors.tertiaryBackground : AppColors.secondaryBackground)
                        .overlay(
                            Capsule()
                                .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                        )
                )
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(component.name), \(component.detail), \(component.isRequired ? "Required" : "Optional")")
    }
}

#Preview("Component Requirement Row") {
    VStack(spacing: 8) {
        ComponentRequirementRow(component: ComponentRequirement(name: "Breadboard", detail: "830 tie-point board", isRequired: true))
        ComponentRequirementRow(component: ComponentRequirement(name: "5V Power Source", detail: "Optional USB board", isRequired: false))
    }
    .padding()
}
