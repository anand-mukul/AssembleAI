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
    var onLaunchInspection: ((AssemblyProject) -> Void)? = nil
    
    @State private var availableProjects: [AssemblyProject] = []
    @State private var selectedProjectID: UUID? = nil
    @State private var pulseScale: CGFloat = 0.95
    @State private var isCameraReady: Bool = true
    
    private let repository = ProjectRepositoryFactory.resolve()
    
    var body: some View {
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
                        .multilineTextAlignment(.center)
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
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProjects()
        }
    }
    
    // MARK: - Viewfinder Hero
    
    private var viewfinderHero: some View {
        ZStack {
            // Outer Pulsing Glow
            Circle()
                .fill(Color.assembleBrandPrimary.opacity(0.10))
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)
            
            Circle()
                .stroke(Color.assembleBrandPrimary.opacity(0.35), lineWidth: 1.5)
                .frame(width: 110, height: 110)
            
            // Optical Frame Marks
            Image(systemName: "viewfinder")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.assembleBrandPrimary)
            
            // Center Reticle
            Circle()
                .fill(Color.assembleBrandPrimary)
                .frame(width: 8, height: 8)
        }
        .frame(height: 150)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
    
    // MARK: - Project Selector Card
    
    private var projectSelectorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("TARGET WORKSPACE PROJECT")
                .sectionHeaderStyle()
            
            if availableProjects.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("Loading projects…")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(AppSpacing.md)
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
                    HStack {
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
                            .foregroundColor(.assembleBrandPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Readiness Card
    
    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PRE-SCAN SETUP")
                .sectionHeaderStyle()
            
            VStack(alignment: .leading, spacing: AppSpacing.mdSm) {
                checklistRow(icon: "sun.max.fill", title: "Bright Workspace", subtitle: "Direct overhead lighting prevents component lead shadows.")
                checklistRow(icon: "iphone.gen3", title: "Optimal Distance", subtitle: "Hold camera 20–35 cm directly above breadboard.")
                checklistRow(icon: "shield.lefthalf.filled", title: "Strictly On-Device", subtitle: "Vision models run on Apple Neural Engine without server uploads.")
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColors.secondaryGroupedBackground)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func checklistRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
            availableProjects = MockProjectData.sampleProjects
            selectedProjectID = availableProjects.first?.id
        }
    }
    
    private func launchInspection() {
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
