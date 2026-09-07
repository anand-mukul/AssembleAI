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
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Sections
    
    private var guidanceAndVerificationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Guidance & Inspection")
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                // Guidance Level Selector
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "slider.horizontal.3", size: 30, iconSize: 15, color: AppColors.badgeBlue)
                        
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
                    .onChange(of: viewModel.guidanceLevelRaw) {
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
                
                Divider().padding(.leading, AppSpacing.dividerLeadingInset)
                
                // Verification Engine Mode
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "camera.badge.ellipsis", size: 30, iconSize: 15, color: AppColors.badgePurple)
                        
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
                    .onChange(of: viewModel.verificationMode) {
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
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.showCameraGrid) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "grid", size: 30, iconSize: 15, color: AppColors.badgeBlue)
                        Text("Alignment Grid Overlay")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.leading, AppSpacing.dividerLeadingInset)
                
                Toggle(isOn: $viewModel.reticlePulsing) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "circle.circle", size: 30, iconSize: 15, color: AppColors.badgeIndigo)
                        Text("Target Reticle Pulse")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.leading, AppSpacing.dividerLeadingInset)
                
                Toggle(isOn: $viewModel.autoTorch) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "flashlight.on.fill", size: 30, iconSize: 15, color: AppColors.badgeOrange)
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
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.hapticsEnabled) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "waveform", size: 30, iconSize: 15, color: AppColors.badgeTeal)
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
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "chart.bar.doc.horizontal.fill", size: 30, iconSize: 15, color: AppColors.badgeGreen)
                        
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
