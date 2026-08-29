//
//  ComponentRequirementRow.swift
//  AssembleAI
//

import SwiftUI

/// Clean requirement item row for Project Details screen.
struct ComponentRequirementRow: View {
    let component: ComponentRequirement
    
    var body: some View {
        HStack(spacing: AppSpacing.mdSm) {
            Image(systemName: component.isRequired ? "circle.fill" : "circle")
                .font(.caption2)
                .foregroundColor(component.isRequired ? .assembleBrandPrimary : AppColors.tertiaryText)
            
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
                .fontWeight(.medium)
                .foregroundColor(component.isRequired ? AppColors.secondaryText : AppColors.tertiaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(AppColors.tertiaryBackground)
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
