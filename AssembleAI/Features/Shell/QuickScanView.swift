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
    @State private var pulseScale: CGFloat = 0.96
    @State private var glowPhase: CGFloat = 0
    @State private var isCameraReady: Bool = true
    
    private let repository = ProjectRepositoryFactory.resolve()
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Hero Viewfinder Centerpiece
                    viewfinderHero
                        .padding(.top, AppSpacing.md)
                    
                    // Header & Value Proposition
                    VStack(spacing: AppSpacing.xs) {
                        Text("Physical Inspection")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Point your camera at the circuit board to track pin connections, orientation, and placement in real time.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
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
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProjects()
        }
    }
    
    // MARK: - Viewfinder Hero
    
    private var viewfinderHero: some View {
        ZStack {
            // Ambient Radial Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.glowPrimary.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .scaleEffect(1.0 + glowPhase * 0.15)
            
            // Outer Pulsing Ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppColors.iconBadgeGradientStart.opacity(0.4), AppColors.iconBadgeGradientEnd.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 130, height: 130)
                .scaleEffect(pulseScale)
            
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                .frame(width: 104, height: 104)
            
            // Optical Frame Marks
            Image(systemName: "viewfinder")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Center Reticle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: AppColors.iconBadgeGradientStart.opacity(0.5), radius: 4)
        }
        .frame(height: 150)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
                glowPhase = 1.0
            }
        }
    }
    
    // MARK: - Project Selector Card
    
    private var projectSelectorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Target Project")
                .sectionHeaderStyle()
            
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
                        GradientIconBadge(
                            iconName: selectedProject?.imageName ?? "cpu",
                            size: 38,
                            iconSize: 17
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Pre-Scan Setup")
                .sectionHeaderStyle()
            
            VStack(alignment: .leading, spacing: AppSpacing.mdSm) {
                checklistRow(icon: "sun.max.fill", title: "Bright Workspace", subtitle: "Direct overhead lighting prevents component lead shadows.")
                checklistRow(icon: "iphone.gen3", title: "Optimal Distance", subtitle: "Hold camera 20–35 cm directly above breadboard.")
                checklistRow(icon: "shield.lefthalf.filled", title: "Strictly On-Device", subtitle: "Vision models run on Apple Neural Engine without server uploads.")
            }
            .appCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func checklistRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            GradientIconBadge(iconName: icon, size: 34, iconSize: 15)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .adaptiveMultiline()
            }
        }
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
