//
//  EmptyProjectsView.swift
//  AssembleAI
//

import SwiftUI

/// Clean, friendly empty state for when no projects or search results are found.
struct EmptyProjectsView: View {
    var title: String = "No projects yet"
    var subtitle: String = "Start your first assembly project and we'll guide you step by step."
    var iconName: String = "viewfinder"
    var buttonTitle: String? = "Explore Projects"
    var onAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 40)
            
            AnimatedHeaderIcon(
                iconName: iconName,
                iconSize: 32,
                circleDiameter: 68
            )
            
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .adaptiveMultiline(alignment: .center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            if let buttonTitle = buttonTitle, let onAction = onAction {
                PrimaryButton(title: buttonTitle, iconName: "plus") {
                    onAction()
                }
                .frame(maxWidth: 220)
                .padding(.top, AppSpacing.xs)
            }
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Empty Projects View") {
    EmptyProjectsView(onAction: {})
}
