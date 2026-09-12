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
                
                // Section 2: Research & Visual History Strategy
                researchStrategySection
                
                // Section 3: Camera & Viewfinder Experience
                cameraViewfinderSection
                
                // Section 4: Haptics & Sensory Feedback
                tactileSection
                
                // Section 5: Data & Diagnostics Link
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
    
    private var researchStrategySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Research & Visual History")
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                // Strategy Selector
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        SemanticIconBadge(iconName: "clock.arrow.circlepath", size: 30, iconSize: 15, color: AppColors.badgeIndigo)
                        
                        Text("Temporal History Strategy")
                            .font(.body)
                            .fontWeight(.medium)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
                    .onChange(of: viewModel.visualHistoryStrategyRaw) {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    
                    Text(strategyDescription(for: viewModel.visualHistoryStrategyRaw))
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .adaptiveMultiline()
                }
                .padding(AppSpacing.md)
                
                // Sliding Window N Frames (Visible when Strategy B is active)
                if viewModel.visualHistoryStrategyRaw == VisualHistoryStrategy.lastNFrames.rawValue {
                    Divider().padding(.leading, AppSpacing.dividerLeadingInset)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            SemanticIconBadge(iconName: "square.stack.3d.forward.dottedline.fill", size: 30, iconSize: 15, color: AppColors.badgeOrange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Window Size (N Frames)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText)
                                Text("Recent visual frames retained in model context")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Stepper("", value: $viewModel.lastNFramesValue, in: 2...15)
                                    .labelsHidden()
                                    .onChange(of: viewModel.lastNFramesValue) {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                
                                Text("\(viewModel.lastNFramesValue)")
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundColor(AppColors.primaryText)
                                    .frame(minWidth: 28, alignment: .trailing)
                            }
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
                                        .background(viewModel.lastNFramesValue == preset ? AppColors.brandPrimary : AppColors.secondaryGroupedBackground)
                                        .foregroundColor(viewModel.lastNFramesValue == preset ? .white : AppColors.primaryText)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(viewModel.lastNFramesValue == preset ? Color.clear : AppColors.borderSubtle, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .appCard(padding: 0)
        }
    }
    
    private func strategyDescription(for rawValue: String) -> String {
        switch rawValue {
        case VisualHistoryStrategy.currentFrame.rawValue:
            return "Strategy A: Single current frame upon hand retraction. Baseline single-frame reasoning (~188 MB peak RAM)."
        case VisualHistoryStrategy.lastNFrames.rawValue:
            return "Strategy B: Sliding FIFO window of the last \(viewModel.lastNFramesValue) frames. Evaluates temporal smoothing vs. token scaling."
        case VisualHistoryStrategy.fullVisualHistory.rawValue:
            return "Strategy C: Unbounded chronological frame accumulation. Evaluates memory limits (triggers Jetsam OOM crash at Step 7 in benchmarks)."
        case VisualHistoryStrategy.compressedStateHistory.rawValue:
            return "Strategy D (AssembleAI Default): State-aware semantic keyframes with structural graph summary (~215 MB bounded RAM)."
        default:
            return "Select temporal visual history architecture for research logging."
        }
    }
    
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
