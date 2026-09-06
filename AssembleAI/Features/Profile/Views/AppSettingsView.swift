//
//  AppSettingsView.swift
//  AssembleAI
//
//  Application settings screen for configuring physical guidance details,
//  camera features, verification engine modes, and haptics.
//

import SwiftUI

/// Clean, human-centered Application Settings screen following Apple Human Interface Guidelines and glassmorphic styling.
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Section 1: Guidance & Verification
                    guidanceAndVerificationSection
                    
                    // Section 2: Camera & Viewfinder Experience
                    cameraViewfinderSection
                    
                    // Section 3: Haptics & Sensory Feedback
                    tactileSection
                    
                    // Section 4: Data & Diagnostics Link
                    diagnosticsSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, 120) // Full clearance above floating tab bar
            }
        }
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Sections
    
    private var guidanceAndVerificationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Guidance & Inspection")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                // Guidance Level Selector
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "slider.horizontal.3", size: 28, iconSize: 13)
                        
                        Text("Guidance Detail")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                    }
                    
                    Picker("Guidance Level", selection: $viewModel.guidanceLevelRaw) {
                        Text("Concise").tag(GuidanceLevel.concise.rawValue)
                        Text("Detailed").tag(GuidanceLevel.detailed.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.guidanceLevelRaw) { _ in
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    
                    Text(viewModel.guidanceLevelRaw == GuidanceLevel.concise.rawValue
                         ? "Short, quick instructions for experienced builders."
                         : "Step-by-step physical placement guidance with pinout notes.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .adaptiveMultiline()
                }
                .padding(AppSpacing.md)
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                // Verification Engine Mode
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "camera.badge.ellipsis", size: 28, iconSize: 13)
                        
                        Text("Verification Mode")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                    }
                    
                    Picker("Verification Mode", selection: $viewModel.verificationMode) {
                        Text("Automated").tag("hybrid")
                        Text("Optical Only").tag("vision")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.verificationMode) { _ in
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    
                    Text(viewModel.verificationMode == "hybrid"
                         ? "Verifies component placement and wire connectivity automatically."
                         : "Uses optical bounding checks against target hardware templates.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .adaptiveMultiline()
                }
                .padding(AppSpacing.md)
            }
            .appCard(padding: 0)
        }
    }
    
    private var cameraViewfinderSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Camera & Viewfinder")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.showCameraGrid) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "grid", size: 28, iconSize: 13)
                        Text("Alignment Grid Overlay")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                Toggle(isOn: $viewModel.reticlePulsing) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "circle.circle", size: 28, iconSize: 13)
                        Text("Target Reticle Pulse")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                Toggle(isOn: $viewModel.autoTorch) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "flashlight.on.fill", size: 28, iconSize: 13)
                        Text("Auto-Torch in Low Light")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
            }
            .appCard(padding: 0)
        }
    }
    
    private var tactileSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Haptics & Sensory")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.hapticsEnabled) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(iconName: "waveform", size: 28, iconSize: 13)
                        Text("Haptic Guidance Feedback")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
            }
            .appCard(padding: 0)
        }
    }
    
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Data & Diagnostics")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    HStack(spacing: AppSpacing.sm) {
                        GradientIconBadge(
                            iconName: "chart.bar.doc.horizontal.fill",
                            size: 28,
                            iconSize: 13,
                            colors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd]
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data, Cache & Telemetry")
                                .font(.body)
                                .foregroundColor(AppColors.primaryText)
                            Text("Manage local storage, clear cache, or export logs")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .appCard(padding: 0)
        }
    }
}

#Preview("App Settings View") {
    NavigationStack {
        AppSettingsView(viewModel: ProfileViewModel())
    }
}
