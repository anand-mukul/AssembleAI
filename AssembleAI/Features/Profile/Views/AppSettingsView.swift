//
//  AppSettingsView.swift
//  AssembleAI
//
//  Application settings screen for configuring physical guidance details,
//  camera features, verification engine modes, and haptics.
//

import SwiftUI

/// Clean, human-centered Application Settings screen following Apple Human Interface Guidelines.
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
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
        .background(AppColors.appBackground.ignoresSafeArea())
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
                    HStack {
                        Label("Guidance Detail", systemImage: "slider.horizontal.3")
                            .font(.body)
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
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                // Verification Engine Mode
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Label("Verification Mode", systemImage: "camera.badge.ellipsis")
                            .font(.body)
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
                    Label("Alignment Grid Overlay", systemImage: "grid")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                Toggle(isOn: $viewModel.reticlePulsing) {
                    Label("Target Reticle Pulse", systemImage: "circle.circle")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                Toggle(isOn: $viewModel.autoTorch) {
                    Label("Auto-Torch in Low Light", systemImage: "flashlight.on.fill")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
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
                    Label("Haptic Guidance Feedback", systemImage: "waveform")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
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
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.assembleBrandPrimary)
                        
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
