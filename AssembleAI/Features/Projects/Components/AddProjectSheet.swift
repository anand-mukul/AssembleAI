//
//  AddProjectSheet.swift
//  AssembleAI
//

import SwiftUI

/// Native entry point sheet for adding or scanning a new project.
struct AddProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onChooseProject: () -> Void
    
    @State private var showCreator = false
    @State private var showImporter = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
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
            .padding(.top, AppSpacing.lg)
            
            VStack(spacing: AppSpacing.mdSm) {
                PrimaryButton(title: "Choose a Project", iconName: "folder") {
                    dismiss()
                    onChooseProject()
                }
                
                SecondaryButton(title: "Create New Project", iconName: "pencil.and.list.clipboard") {
                    showCreator = true
                }
                
                SecondaryButton(title: "Import from Guide", iconName: "doc.text.magnifyingglass") {
                    showImporter = true
                }
            }
            .padding(.top, AppSpacing.sm)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.secondaryGroupedBackground.ignoresSafeArea())
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .fullScreenCover(isPresented: $showCreator) {
            ProjectCreatorView()
        }
        .fullScreenCover(isPresented: $showImporter) {
            ImportGuideSheetView()
        }
    }
}

/// Convenience wrapper that opens ProjectCreatorView pre-configured for import mode.
struct ImportGuideSheetView: View {
    @StateObject private var viewModel: ProjectCreatorViewModel
    
    init() {
        let vm = ProjectCreatorViewModel()
        vm.creationMode = .importGuide
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ProjectCreatorView()
    }
}

#Preview("Add Project Sheet") {
    Text("Host View")
        .sheet(isPresented: .constant(true)) {
            AddProjectSheet(onChooseProject: {})
        }
}
