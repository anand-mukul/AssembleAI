//
//  AddProjectSheet.swift
//  AssembleAI
//

import SwiftUI

/// Native entry point sheet for adding or scanning a new project.
struct AddProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onChooseProject: () -> Void
    
    @State private var showScanPlaceholder = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Drag indicator
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.sm)
            
            VStack(spacing: AppSpacing.xs) {
                Text("Add Project")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Choose how you'd like to begin your assembly.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.top, AppSpacing.xs)
            
            VStack(spacing: AppSpacing.mdSm) {
                PrimaryButton(title: "Choose a Project", iconName: "folder") {
                    dismiss()
                    onChooseProject()
                }
                
                SecondaryButton(title: "Scan Instructions (Preview)", iconName: "viewfinder") {
                    showScanPlaceholder = true
                }
            }
            .padding(.top, AppSpacing.sm)
            
            if showScanPlaceholder {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.warning)
                    Text("Instruction scanning available in next release.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .transition(.opacity)
            }
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .presentationDetents([.height(340)])
        .presentationCornerRadius(28)
    }
}

#Preview("Add Project Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            AddProjectSheet(onChooseProject: {})
        }
}
