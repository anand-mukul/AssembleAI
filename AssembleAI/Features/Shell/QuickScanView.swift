//
//  QuickScanView.swift
//  AssembleAI
//

import SwiftUI

/// Dedicated visual inspection launcher for Tab 2 ("Scan").
/// Provides camera readiness diagnostics, active project selection, and one-tap optical inspection launch.
@MainActor
struct QuickScanView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onLaunchInspection: ((AssemblyProject) -> Void)? = nil
    
    @State private var availableProjects: [AssemblyProject] = []
    @State private var selectedProjectID: UUID? = nil
    @State private var pulseScale: CGFloat = 0.98
    @State private var showProjectPickerSheet: Bool = false
    
    private let repository = ProjectRepositoryFactory.resolve()
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Hero Viewfinder Centerpiece
                viewfinderHero
                    .padding(.top, AppSpacing.sm)
                
                // Header & Value Proposition
                VStack(spacing: AppSpacing.xs) {
                    Text("Optical Verification")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Align camera directly above your workpiece to track components, fasteners, and physical connections in real time.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .adaptiveMultiline(alignment: .center)
                        .padding(.horizontal, AppSpacing.md)
                }
                
                // Target Project Selector Card
                projectSelectorCard
                
                // Pre-Scan Readiness Checklist
                readinessCard
                
                // Launch Action
                let buttonTitle = (selectedProject?.isActive == true)
                    ? "Resume Assembly Inspection"
                    : "Start Visual Inspection"
                PrimaryButton(title: buttonTitle, iconName: "camera.viewfinder") {
                    launchInspection()
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, 100)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProjectPickerSheet) {
            TargetProjectPickerSheet(
                projects: availableProjects,
                selectedProjectID: $selectedProjectID
            )
        }
        .onAppear {
            Task {
                await loadProjects()
            }
        }
        .task {
            await loadProjects()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AssemblySessionUpdated"))) { _ in
            Task {
                await loadProjects()
            }
        }
    }
    
    // MARK: - Viewfinder Hero
    
    private var viewfinderHero: some View {
        ZStack {
            // Subtle ambient halo
            Circle()
                .fill(Color.assembleBrandPrimary.opacity(0.08))
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)
            
            // Optical reticle outer ring
            Circle()
                .stroke(Color.assembleBrandPrimary.opacity(0.35), lineWidth: 1)
                .frame(width: 110, height: 110)
            
            // Optical Frame Marks
            Image(systemName: "viewfinder")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(.assembleBrandPrimary)
            
            // Center Reticle Crosshair
            Circle()
                .fill(Color.assembleBrandPrimary)
                .frame(width: 6, height: 6)
        }
        .frame(height: 140)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        }
    }
    
    // MARK: - Project Selector Card
    
    private var projectSelectorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Target Project")
                .standardSectionHeader()
            
            if availableProjects.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("Loading projects…")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .appCard(padding: 0)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showProjectPickerSheet = true
                } label: {
                    HStack(spacing: AppSpacing.mdSm) {
                        SemanticIconBadge(
                            iconName: selectedProject?.domain.iconName ?? selectedProject?.imageName ?? "cpu",
                            size: 38,
                            iconSize: 18,
                            color: selectedProject?.domain.badgeColor ?? AppColors.badgeBlue
                        )
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedProject?.title ?? "Select Project")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(1)
                            
                            if let project = selectedProject {
                                HStack(spacing: 6) {
                                    Text(project.domain.displayName)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.tertiaryText)
                                    
                                    Text("\(project.totalSteps) steps")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.tertiaryText)
                                    
                                    DifficultyBadge(difficulty: project.difficulty)
                                }
                                .lineLimit(1)
                            } else {
                                Text("Choose target project (\(availableProjects.count) available)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Apple HIG circular selector accessory
                        ZStack {
                            Circle()
                                .fill(AppColors.tertiaryBackground)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .padding(AppSpacing.md)
                    .appCard(padding: 0)
                }
                .buttonStyle(ScaleButtonStyle(enableHaptic: false))
                .accessibilityLabel(selectedProject != nil ? "Target Project: \(selectedProject!.title), \(selectedProject!.category), double tap to change" : "Select Target Project")
                .accessibilityHint("Opens project selector sheet")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Readiness Card
    
    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Pre-Scan Setup")
                .standardSectionHeader()
            
            VStack(alignment: .leading, spacing: 0) {
                checklistRow(
                    icon: "sun.max.fill",
                    title: "Bright Workspace",
                    subtitle: "Direct overhead lighting prevents deep workpiece and component shadows.",
                    color: AppColors.badgeOrange
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                checklistRow(
                    icon: "iphone.gen3",
                    title: "Optimal Distance",
                    subtitle: "Hold camera 20–35 cm directly above your workpiece.",
                    color: AppColors.badgeBlue
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                checklistRow(
                    icon: "shield.lefthalf.filled",
                    title: "Strictly On-Device",
                    subtitle: "Vision models run on Apple Neural Engine without server uploads.",
                    color: AppColors.badgeGreen
                )
            }
            .appCard(padding: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func checklistRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            SemanticIconBadge(iconName: icon, size: 30, iconSize: 15, color: color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(2)
                    .adaptiveMultiline()
            }
        }
        .padding(AppSpacing.md)
    }
    
    // MARK: - Helpers
    
    private var selectedProject: AssemblyProject? {
        if let id = selectedProjectID {
            return availableProjects.first(where: { $0.id == id })
        }
        return availableProjects.first
    }
    
    private func loadProjects() async {
        do {
            let projects = try await repository.fetchProjects()
            availableProjects = projects
            if selectedProjectID == nil {
                selectedProjectID = projects.first(where: { $0.isActive })?.id ?? projects.first?.id
            }
        } catch {
            availableProjects = []
            selectedProjectID = nil
        }
    }
    
    private func launchInspection() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let project = selectedProject ?? availableProjects.first else { return }
        
        Task {
            let fullProject = (try? await repository.fetchProject(byId: project.id)) ?? project
            if let onLaunch = onLaunchInspection {
                onLaunch(fullProject)
            } else {
                let stepIdx = max(0, min(fullProject.completedSteps, max(0, fullProject.steps.count - 1)))
                let currentSummary = fullProject.steps.indices.contains(stepIdx) ? fullProject.steps[stepIdx] : fullProject.steps.first
                let step = currentSummary.map { summary in
                    AssemblyStep(
                        id: summary.id,
                        projectId: fullProject.id,
                        stepOrder: summary.stepOrder,
                        title: summary.title,
                        instruction: summary.instruction,
                        visualContract: summary.visualContract
                    )
                } ?? AssemblyStep(
                    projectId: fullProject.id,
                    stepOrder: stepIdx + 1,
                    title: "Inspect Component Placement",
                    instruction: "Position camera over workpiece."
                )
                router.navigateToCamera(step: step, project: fullProject)
            }
        }
    }
}

// MARK: - Target Project Picker Sheet (Apple HIG Standard)

/// Dedicated, scalable project picker sheet adhering strictly to Apple HIG modal presentation patterns.
/// Gracefully scales to 60+ projects with responsive instant search, domain segmentation, and tactile haptic feedback.
struct TargetProjectPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projects: [AssemblyProject]
    @Binding var selectedProjectID: UUID?
    
    @State private var searchText: String = ""
    @State private var selectedDomainFilter: DomainFilterOption = .all
    
    enum DomainFilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case electronics = "Electronics"
        case physical = "Physical"
        case hybrid = "Hybrid"
        
        var id: String { rawValue }
        
        var domain: AssemblyDomain? {
            switch self {
            case .all: return nil
            case .electronics: return .electronics
            case .physical: return .physical
            case .hybrid: return .hybrid
            }
        }
    }
    
    private var filteredProjects: [AssemblyProject] {
        projects.filter { project in
            let matchesSearch: Bool
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = project.title.lowercased().contains(query) ||
                                project.category.lowercased().contains(query) ||
                                project.subtitle.lowercased().contains(query)
            }
            
            let matchesDomain: Bool
            if let targetDomain = selectedDomainFilter.domain {
                matchesDomain = project.domain == targetDomain
            } else {
                matchesDomain = true
            }
            
            return matchesSearch && matchesDomain
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Domain Segmented Filter
                Picker("Domain", selection: $selectedDomainFilter) {
                    ForEach(DomainFilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
                .onChange(of: selectedDomainFilter) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                
                // Active count header
                HStack {
                    Text("\(filteredProjects.count) \(filteredProjects.count == 1 ? "project" : "projects")")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                    
                    if selectedDomainFilter != .all || !searchText.isEmpty {
                        Button("Reset") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                                selectedDomainFilter = .all
                                searchText = ""
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.assembleBrandPrimary)
                    }
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.vertical, AppSpacing.xs)
                
                // Content: Scrollable List or Empty State
                if filteredProjects.isEmpty {
                    emptySearchState
                } else {
                    projectsList
                }
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search \(projects.count) projects…"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.assembleBrandPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var projectsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(filteredProjects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    private func projectRow(_ project: AssemblyProject) -> some View {
        let isSelected = project.id == selectedProjectID
        
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                selectedProjectID = project.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dismiss()
            }
        } label: {
            HStack(spacing: AppSpacing.mdSm) {
                // Semantic Icon Badge
                SemanticIconBadge(
                    iconName: project.domain.iconName,
                    size: 38,
                    iconSize: 18,
                    color: project.domain.badgeColor
                )
                
                // Project Details
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(project.title)
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        if project.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.assembleBrandPrimary.opacity(0.12))
                                .foregroundColor(.assembleBrandPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(project.domain.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("\(project.totalSteps) steps")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        DifficultyBadge(difficulty: project.difficulty)
                        
                        if project.completedSteps > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(AppColors.tertiaryText)
                            
                            Text(project.progressText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .foregroundColor(project.isCompleted ? AppColors.success : AppColors.secondaryText)
                        }
                    }
                    .lineLimit(1)
                }
                
                Spacer()
                
                // Selection Radio/Check Indicator
                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.assembleBrandPrimary)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .strokeBorder(AppColors.borderStrong, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(isSelected ? Color.assembleBrandPrimary.opacity(0.08) : AppColors.secondaryGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.assembleBrandPrimary.opacity(0.45) : AppColors.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(enableHaptic: false))
    }
    
    private var emptySearchState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(AppColors.secondaryText.opacity(0.6))
                .padding(.bottom, AppSpacing.xs)
            
            Text("No Projects Found")
                .font(.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            if !searchText.isEmpty || selectedDomainFilter != .all {
                Button("Reset Filters") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                        searchText = ""
                        selectedDomainFilter = .all
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.assembleBrandPrimary)
                .padding(.top, AppSpacing.xs)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty && selectedDomainFilter != .all {
            return "No projects match \"\(searchText)\" under \(selectedDomainFilter.rawValue)."
        } else if !searchText.isEmpty {
            return "No projects match \"\(searchText)\"."
        } else {
            return "No projects available in \(selectedDomainFilter.rawValue)."
        }
    }
}

#Preview("Quick Scan View") {
    NavigationStack {
        QuickScanView()
            .environmentObject(AppRouter())
    }
}
