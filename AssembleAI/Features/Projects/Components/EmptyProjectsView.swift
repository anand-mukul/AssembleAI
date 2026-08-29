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
        VStack(spacing: AppSpacing.mdLg) {
            Spacer(minLength: 40)
            
            ZStack {
                Circle()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(.assembleBrandPrimary)
            }
            
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if let buttonTitle = buttonTitle, let onAction = onAction {
                Button(action: onAction) {
                    Text(buttonTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.assembleBrandPrimary)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
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
