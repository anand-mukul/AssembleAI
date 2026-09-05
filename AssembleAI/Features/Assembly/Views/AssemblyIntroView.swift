//
//  AssemblyIntroView.swift
//  AssembleAI
//

import SwiftUI

/// Pre-assembly preparation screen ensuring workspace, components, and camera readiness before inspection starts.
struct AssemblyIntroView: View {
    let project: AssemblyProject
    let onBegin: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Top Cancel / Back Button
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, AppSpacing.sm)
                
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(project.title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.assembleBrandPrimary)
                    
                    Text("Ready to build?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("\(project.totalSteps) guided steps · ~\(project.estimatedMinutes) minutes")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // Preparation Checklist
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Preparation Check")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        checklistRow(title: "Components ready", subtitle: "All required hardware is on hand", icon: "checkmark.circle.fill")
                        checklistRow(title: "Camera available", subtitle: "Camera access is operational", icon: "checkmark.circle.fill")
                        checklistRow(title: "Workspace visible", subtitle: "Assembly area is clean and well-lit", icon: "checkmark.circle.fill")
                    }
                    .appCard()
                }
                
                // Before we begin notice
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Before we begin")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Make sure your components are visible and your workspace has enough light. The visual assistant will guide you step by step.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appCard(backgroundColor: AppColors.secondaryBackground)
                
                Spacer(minLength: AppSpacing.lg)
                
                PrimaryButton(title: "Begin", iconName: "play.fill") {
                    onBegin()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private func checklistRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Assembly Intro View") {
    AssemblyIntroView(
        project: MockProjectData.sampleProjects[0],
        onBegin: {},
        onBack: {}
    )
}
