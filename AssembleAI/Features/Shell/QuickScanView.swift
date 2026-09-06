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
    @State private var isCameraReady: Bool = true
    
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
                    
                    Text("Align camera directly above breadboard to track pin connections, wire rows, and polarities in real time.")
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
                PrimaryButton(title: "Start Visual Inspection", iconName: "camera.viewfinder") {
                    launchInspection()
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProjects()
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
                .padding(AppSpacing.md)
                .appCard()
            } else {
                Menu {
                    ForEach(availableProjects) { project in
                        Button {
                            selectedProjectID = project.id
                        } label: {
                            HStack {
                                Text(project.title)
                                if project.id == selectedProjectID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.mdSm) {
                        SemanticIconBadge(
                            iconName: selectedProject?.imageName ?? "cpu",
                            size: 32,
                            iconSize: 16,
                            color: AppColors.badgeBlue
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProject?.title ?? "Select Project")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryText)
                            Text(selectedProject?.subtitle ?? "Tap to choose target circuit")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .appCard()
                }
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
                    subtitle: "Direct overhead lighting prevents component lead shadows.",
                    color: AppColors.badgeOrange
                )
                
                Divider()
                    .padding(.leading, AppSpacing.dividerLeadingInset)
                
                checklistRow(
                    icon: "iphone.gen3",
                    title: "Optimal Distance",
                    subtitle: "Hold camera 20–35 cm directly above breadboard.",
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
            let fallbackProjects = BundledProjectRepository.bundledProjects
            availableProjects = !fallbackProjects.isEmpty ? fallbackProjects : SampleProjectData.sampleProjects
            selectedProjectID = availableProjects.first?.id
        }
    }
    
    private func launchInspection() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let project = selectedProject ?? availableProjects.first else { return }
        
        if let onLaunch = onLaunchInspection {
            onLaunch(project)
        } else {
            let step = project.steps.first.map { summary in
                AssemblyStep(
                    id: summary.id,
                    projectId: project.id,
                    stepOrder: summary.stepOrder,
                    title: summary.title,
                    instruction: summary.instruction,
                    visualContract: summary.visualContract
                )
            } ?? AssemblyStep(
                projectId: project.id,
                stepOrder: 1,
                title: "Inspect Component Placement",
                instruction: "Position camera over workpiece."
            )
            router.navigateToCamera(step: step)
        }
    }
}

#Preview("Quick Scan View") {
    NavigationStack {
        QuickScanView()
            .environmentObject(AppRouter())
    }
}
