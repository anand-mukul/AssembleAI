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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
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
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Preparation Check")
                        .standardSectionHeader()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        checklistRow(title: "Components ready", subtitle: "All required hardware is on hand", icon: "checkmark")
                        Divider().padding(.leading, 56)
                        checklistRow(title: "Camera available", subtitle: "Camera access is operational", icon: "camera")
                        Divider().padding(.leading, 56)
                        checklistRow(title: "Workspace visible", subtitle: "Assembly area is clean and well-lit", icon: "lightbulb")
                    }
                    .appCard()
                }
                
                // Before we begin notice
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Before We Begin")
                        .standardSectionHeader()
                    
                    Text("Make sure your components are visible and your workspace has enough light. The visual assistant will guide you step by step.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .appCard()
                }
                
                Spacer(minLength: AppSpacing.lg)
                
                PrimaryButton(title: "Begin", iconName: "play.fill") {
                    onBegin()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
    }
    
    private func checklistRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            SemanticIconBadge(systemName: icon, tintColor: AppColors.badgeGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Assembly Intro View") {
    AssemblyIntroView(
        project: MockProjectData.previewProject,
        onBegin: {},
        onBack: {}
    )
}
