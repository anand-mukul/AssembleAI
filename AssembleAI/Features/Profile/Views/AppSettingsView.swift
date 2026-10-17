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
        Form {
            // Section 1: Guidance & Verification
            guidanceAndVerificationSection
            
            // Section 2: Research & Visual History Strategy
            researchStrategySection
            
            // Section 3: Camera & Viewfinder Experience
            cameraViewfinderSection
            
            // Section 4: Haptics & Sensory Feedback
            tactileSection
            
            // Section 5: Data & Diagnostics Link
            diagnosticsSection
        }
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Sections
    
    private var guidanceAndVerificationSection: some View {
        Section {
            // Guidance Level Selector
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "slider.horizontal.3", size: 30, iconSize: 15, color: AppColors.badgeBlue)
                    
                    Text("Guidance Detail")
                        .font(.body)
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
            }
            .padding(.vertical, 4)
            
            // Verification Engine Mode
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "camera.badge.ellipsis", size: 30, iconSize: 15, color: AppColors.badgePurple)
                    
                    Text("Verification Mode")
                        .font(.body)
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
            }
            .padding(.vertical, 4)
        } header: {
            Text("Guidance & Inspection")
        } footer: {
            Text(viewModel.guidanceLevelRaw == GuidanceLevel.concise.rawValue
                 ? "Concise: Short, quick directives for experienced builders."
                 : "Detailed: Step-by-step physical placement guidance with pinout notes.")
        }
    }
    
    private var researchStrategySection: some View {
        Section {
            // Strategy Selector
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "clock.arrow.circlepath", size: 30, iconSize: 15, color: AppColors.badgeIndigo)
                    
                    Text("Temporal History")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                }
                
                Picker("Strategy", selection: $viewModel.visualHistoryStrategyRaw) {
                    Text("Strategy A: Current Frame").tag(VisualHistoryStrategy.currentFrame.rawValue)
                    Text("Strategy B: Last N Frames").tag(VisualHistoryStrategy.lastNFrames.rawValue)
                    Text("Strategy C: Full History").tag(VisualHistoryStrategy.fullVisualHistory.rawValue)
                    Text("Strategy D: Compressed").tag(VisualHistoryStrategy.compressedStateHistory.rawValue)
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.visualHistoryStrategyRaw) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .padding(.vertical, 4)
            
            // Sliding Window N Frames (Visible when Strategy B is active)
            if viewModel.visualHistoryStrategyRaw == VisualHistoryStrategy.lastNFrames.rawValue {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        SemanticIconBadge(iconName: "square.stack.3d.forward.dottedline.fill", size: 30, iconSize: 15, color: AppColors.badgeOrange)
                        
                        Text("Window Size")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Stepper("", value: $viewModel.lastNFramesValue, in: 2...15)
                            .labelsHidden()
                            .onChange(of: viewModel.lastNFramesValue) {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        
                        Text("\(viewModel.lastNFramesValue) frames")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // Preset Quick Selectors (N = 3, 5, 10)
                    HStack(spacing: AppSpacing.sm) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        ForEach([3, 5, 10], id: \.self) { preset in
                            Button {
                                viewModel.lastNFramesValue = preset
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text("N = \(preset)")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(viewModel.lastNFramesValue == preset ? AppColors.brandPrimary : AppColors.secondaryBackground)
                                    .foregroundColor(viewModel.lastNFramesValue == preset ? .white : AppColors.primaryText)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Research & Visual History")
        } footer: {
            Text(strategyDescription(for: viewModel.visualHistoryStrategyRaw))
        }
    }
    
    private func strategyDescription(for rawValue: String) -> String {
        switch rawValue {
        case VisualHistoryStrategy.currentFrame.rawValue:
            return "Strategy A: Single current frame upon hand retraction. Baseline single-frame reasoning (~188 MB peak RAM)."
        case VisualHistoryStrategy.lastNFrames.rawValue:
            return "Strategy B: Sliding FIFO window of the last \(viewModel.lastNFramesValue) frames. Evaluates temporal smoothing vs. token scaling."
        case VisualHistoryStrategy.fullVisualHistory.rawValue:
            return "Strategy C: Unbounded chronological frame accumulation. Evaluates memory limits in benchmarks."
        case VisualHistoryStrategy.compressedStateHistory.rawValue:
            return "Strategy D (AssembleAI Default): State-aware semantic keyframes with structural graph summary (~215 MB bounded RAM)."
        default:
            return "Select temporal visual history architecture for research logging."
        }
    }
    
    private var cameraViewfinderSection: some View {
        Section {
            Toggle(isOn: $viewModel.showCameraGrid) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "grid", size: 30, iconSize: 15, color: AppColors.badgeBlue)
                    Text("Alignment Grid Overlay")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            Toggle(isOn: $viewModel.reticlePulsing) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "circle.circle", size: 30, iconSize: 15, color: AppColors.badgeIndigo)
                    Text("Target Reticle Pulse")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
            
            Toggle(isOn: $viewModel.autoTorch) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "flashlight.on.fill", size: 30, iconSize: 15, color: AppColors.badgeOrange)
                    Text("Auto-Torch in Low Light")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
        } header: {
            Text("Camera & Viewfinder")
        }
    }
    
    private var tactileSection: some View {
        Section {
            Toggle(isOn: $viewModel.hapticsEnabled) {
                HStack(spacing: AppSpacing.sm) {
                    SemanticIconBadge(iconName: "waveform", size: 30, iconSize: 15, color: AppColors.badgeTeal)
                    Text("Haptic Guidance Feedback")
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
        } header: {
            Text("Haptics & Sensory")
        } footer: {
            Text("Provides subtle tactile confirmation when physical components are correctly placed and verified.")
        }
    }
    
    private var diagnosticsSection: some View {
        Section {
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
                }
            }
        } header: {
            Text("Data & Diagnostics")
        }
    }
}

#Preview("App Settings View") {
    NavigationStack {
        AppSettingsView(viewModel: ProfileViewModel())
    }
}
