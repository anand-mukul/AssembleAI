//
//  ProjectCreatorView.swift
//  AssembleAI
//

import SwiftUI

/// Multi-step project creation flow supporting both manual entry and AI-assisted guide import.
struct ProjectCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProjectCreatorViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
                
                // Content
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        switch viewModel.currentStep {
                        case .metadata:
                            metadataSection
                        case .components:
                            componentsSection
                        case .steps:
                            stepsSection
                        case .review:
                            reviewSection
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                // Validation errors
                if !viewModel.validationErrors.isEmpty {
                    validationBanner
                }
                
                // Bottom navigation
                bottomBar
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle(viewModel.creationMode == .importGuide ? "Import Guide" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            .alert("Project Saved", isPresented: .init(
                get: { viewModel.savedProject != nil },
                set: { if !$0 { dismiss() } }
            )) {
                Button("Done") { dismiss() }
            } message: {
                Text("'\(viewModel.savedProject?.title ?? "Project")' has been created and is ready for assembly.")
            }
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(ProjectCreatorViewModel.CreatorStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(step.rawValue <= viewModel.currentStep.rawValue
                              ? Color.assembleBrandPrimary
                              : AppColors.border)
                        .frame(height: 3)
                    
                    Text(step.title)
                        .font(.caption2)
                        .fontWeight(step == viewModel.currentStep ? .semibold : .regular)
                        .foregroundColor(step.rawValue <= viewModel.currentStep.rawValue
                                         ? AppColors.primaryText
                                         : AppColors.tertiaryText)
                }
            }
        }
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Creation mode picker
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("How would you like to start?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ProjectCreatorViewModel.CreationMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.creationMode = mode
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: mode.iconName)
                                    .font(.title3)
                                Text(mode.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(mode.description)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                    .fill(viewModel.creationMode == mode
                                          ? Color.assembleBrandPrimary.opacity(0.1)
                                          : AppColors.secondaryBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                    .stroke(viewModel.creationMode == mode
                                            ? Color.assembleBrandPrimary
                                            : AppColors.border, lineWidth: 1)
                            )
                        }
                        .foregroundColor(viewModel.creationMode == mode
                                         ? Color.assembleBrandPrimary
                                         : AppColors.primaryText)
                    }
                }
            }
            
            if viewModel.creationMode == .importGuide {
                importSection
            } else {
                manualMetadataFields
            }
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Format picker
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Source Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                Picker("Format", selection: $viewModel.selectedFormat) {
                    ForEach([GuideSourceFormat.markdown, .plainText], id: \.rawValue) { format in
                        Label(format.rawValue, systemImage: format.iconName)
                            .tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Domain picker
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Assembly Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                Picker("Domain", selection: $viewModel.selectedDomain) {
                    ForEach(AssemblyDomain.allCases, id: \.rawValue) { domain in
                        Label(domain.displayName, systemImage: domain.iconName)
                            .tag(domain)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Text input
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Paste Guide Content")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                TextEditor(text: $viewModel.importText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(AppColors.secondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if viewModel.importText.isEmpty {
                            Text("# My LED Circuit\n\n## Components\n- 220Ω Resistor — 1/4W\n- Red LED — 5mm\n\n## Step 1: Insert Resistor\nPlace the resistor into Row 10E...")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(AppColors.placeholderText)
                                .padding(AppSpacing.sm)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
            
            // Parse button
            PrimaryButton(
                title: viewModel.isIngesting ? "Parsing Guide..." : "Parse Guide",
                iconName: "sparkles",
                isLoading: viewModel.isIngesting,
                isDisabled: viewModel.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.startIngestion() }
            }
            
            // Ingestion result preview
            if let result = viewModel.ingestionResult {
                ingestionResultCard(result)
            }
            
            // Ingestion error
            if let error = viewModel.ingestionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(AppColors.error.opacity(0.08))
                )
            }
        }
    }
    
    // MARK: - Ingestion Result Card
    
    private func ingestionResultCard(_ result: IngestionResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: result.isHighConfidence ? "checkmark.seal.fill" : "info.circle.fill")
                    .foregroundColor(result.isHighConfidence ? AppColors.success : AppColors.warning)
                Text("Extraction Complete")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(result.confidence * 100))% confidence")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(result.isHighConfidence ? AppColors.success : AppColors.warning)
            }
            
            HStack(spacing: AppSpacing.md) {
                Label("\(result.project.steps.count) steps", systemImage: "list.number")
                Label("\(result.project.components.count) parts", systemImage: "cpu")
                Label("\(result.processingTimeMs)ms", systemImage: "timer")
            }
            .font(.caption)
            .foregroundColor(AppColors.secondaryText)
            
            if !result.warnings.isEmpty {
                ForEach(result.warnings) { warning in
                    HStack(spacing: 4) {
                        Image(systemName: warning.severity == .critical ? "exclamationmark.triangle" : "info.circle")
                            .font(.caption2)
                        Text(warning.message)
                            .font(.caption2)
                    }
                    .foregroundColor(warning.severity == .critical ? AppColors.error : AppColors.secondaryText)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.secondaryBackground)
        )
    }
    
    // MARK: - Manual Metadata Fields
    
    private var manualMetadataFields: some View {
        VStack(spacing: AppSpacing.md) {
            formField("Project Title", text: $viewModel.projectTitle, placeholder: "LED Circuit Board")
            formField("Description", text: $viewModel.projectDescription, placeholder: "Build a simple LED circuit...", isMultiline: true)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Assembly Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                Picker("Domain", selection: $viewModel.selectedDomain) {
                    ForEach(AssemblyDomain.allCases, id: \.rawValue) { domain in
                        Label(domain.displayName, systemImage: domain.iconName)
                            .tag(domain)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Difficulty")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                    ForEach(Difficulty.allCases, id: \.rawValue) { diff in
                        Text(diff.rawValue).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Stepper("Estimated Time: \(viewModel.estimatedMinutes) min",
                    value: $viewModel.estimatedMinutes, in: 5...180, step: 5)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryText)
        }
    }
    
    // MARK: - Components Section
    
    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Bill of Materials")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Button(action: { viewModel.addComponent() }) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if viewModel.components.isEmpty {
                emptyStateCard(
                    icon: "cpu",
                    title: "No Components",
                    message: "Add the parts needed for this assembly."
                )
            } else {
                ForEach($viewModel.components) { $component in
                    componentRow(component: $component)
                }
                .onDelete(perform: viewModel.removeComponent)
                .onMove(perform: viewModel.moveComponent)
            }
        }
    }
    
    private func componentRow(component: Binding<ProjectCreatorViewModel.EditableComponent>) -> some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                TextField("Component name", text: component.name)
                    .font(.body)
                
                Stepper("×\(component.wrappedValue.quantity)",
                        value: component.quantity, in: 1...99)
                    .font(.caption)
                    .fixedSize()
            }
            
            TextField("Detail (optional)", text: component.detail)
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(AppColors.secondaryBackground)
        )
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Assembly Steps")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Button(action: { viewModel.addStep() }) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if viewModel.assemblySteps.isEmpty {
                emptyStateCard(
                    icon: "list.number",
                    title: "No Steps",
                    message: "Add the sequential assembly instructions."
                )
            } else {
                ForEach(Array(viewModel.assemblySteps.enumerated()), id: \.element.id) { index, _ in
                    stepRow(index: index)
                }
                .onDelete(perform: viewModel.removeStep)
                .onMove(perform: viewModel.moveStep)
            }
        }
    }
    
    private func stepRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Step \(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.assembleBrandPrimary)
                Spacer()
            }
            
            TextField("Step title", text: $viewModel.assemblySteps[index].title)
                .font(.body)
                .fontWeight(.medium)
            
            TextField("Instruction details...", text: $viewModel.assemblySteps[index].instruction, axis: .vertical)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(3...6)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(AppColors.secondaryBackground)
        )
    }
    
    // MARK: - Review Section
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Project summary
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Project Summary")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                
                VStack(alignment: .leading, spacing: 6) {
                    reviewRow(label: "Title", value: viewModel.projectTitle)
                    reviewRow(label: "Domain", value: viewModel.selectedDomain.displayName)
                    reviewRow(label: "Difficulty", value: viewModel.selectedDifficulty.rawValue)
                    reviewRow(label: "Est. Time", value: "\(viewModel.estimatedMinutes) min")
                    reviewRow(label: "Components", value: "\(viewModel.components.count)")
                    reviewRow(label: "Steps", value: "\(viewModel.assemblySteps.count)")
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            
            // Step list preview
            if !viewModel.assemblySteps.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Steps Preview")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    ForEach(Array(viewModel.assemblySteps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.assembleBrandPrimary))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !step.instruction.isEmpty {
                                    Text(step.instruction)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Shared Components
    
    private func formField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        isMultiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
            
            if isMultiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(AppColors.secondaryBackground)
                    )
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(AppColors.secondaryBackground)
                    )
            }
        }
    }
    
    private func reviewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
        }
    }
    
    private func emptyStateCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.tertiaryText)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
        )
    }
    
    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.validationErrors, id: \.self) { error in
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption)
                }
            }
        }
        .foregroundColor(AppColors.error)
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.error.opacity(0.08))
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            if viewModel.canGoBack {
                SecondaryButton(title: "Back", iconName: "chevron.left") {
                    viewModel.goBack()
                }
            }
            
            if viewModel.isOnReviewStep {
                PrimaryButton(
                    title: viewModel.isSaving ? "Saving..." : "Create Project",
                    iconName: "checkmark.circle.fill",
                    isLoading: viewModel.isSaving
                ) {
                    Task { await viewModel.saveProject() }
                }
            } else {
                PrimaryButton(title: "Continue", iconName: "chevron.right") {
                    viewModel.goForward()
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, AppSpacing.md)
        .background(
            AppColors.appBackground
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Preview

#Preview("Project Creator — Manual") {
    ProjectCreatorView()
}
