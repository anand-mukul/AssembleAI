//
//  AppSettingsView.swift
//  AssembleAI
//
//  Application settings screen for configuring physical guidance details,
//  research visual-history experiment strategies, camera features, and haptics.
//

import SwiftUI

/// Application settings screen for configuring physical guidance details, camera features, verification engine modes, and haptics.
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Section 1: Guidance & Verification Engine
                guidanceAndVerificationSection
                
                // Section 2: Research Visual History Experiment Strategy
                researchExperimentSection
                
                // Section 3: Camera & Viewfinder Experience
                cameraViewfinderSection
                
                // Section 4: Tactile & Audio Feedback
                tactileSection
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Sections
    
    private var guidanceAndVerificationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("PHYSICAL GUIDANCE & VERIFICATION")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                // Guidance Level Selector
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Label("Guidance Detail Level", systemImage: "slider.horizontal.3")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                    }
                    
                    Picker("Guidance Level", selection: $viewModel.guidanceLevelRaw) {
                        Text("Concise").tag(GuidanceLevel.concise.rawValue)
                        Text("Detailed").tag(GuidanceLevel.detailed.rawValue)
                    }
                    .pickerStyle(.segmented)
                    
                    Text(viewModel.guidanceLevelRaw == GuidanceLevel.concise.rawValue
                         ? "Short, 1-2 sentence corrective instructions."
                         : "Comprehensive explanations including mechanical context.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                // Verification Engine Mode
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Label("Verification Engine", systemImage: "cpu")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                    }
                    
                    Picker("Verification Mode", selection: $viewModel.verificationMode) {
                        Text("Hybrid Engine").tag("hybrid")
                        Text("Optical Only").tag("vision")
                        Text("Demo Mock").tag("mock")
                    }
                    .pickerStyle(.segmented)
                    
                    Text(verificationModeDescription)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(AppSpacing.md)
            }
            .appCard(padding: 0)
        }
    }
    
    private var researchExperimentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("RESEARCH EXPERIMENT STRATEGY")
                    .sectionHeaderStyle()
                Spacer()
                Text("Study Variable")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.assembleBrandPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.assembleBrandPrimary.opacity(0.12)))
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Label("Visual History Strategy", systemImage: "eye.trianglebadge.exclamationmark")
                            .font(.body)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                    }
                    
                    Picker("Strategy", selection: $viewModel.visualHistoryStrategyRaw) {
                        Text("A: Current Frame").tag(VisualHistoryStrategy.currentFrame.rawValue)
                        Text("B: Last N Frames").tag(VisualHistoryStrategy.lastNFrames.rawValue)
                        Text("C: Full Visual History").tag(VisualHistoryStrategy.fullVisualHistory.rawValue)
                        Text("D: Compressed State").tag(VisualHistoryStrategy.compressedStateHistory.rawValue)
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 4)
                    
                    if viewModel.visualHistoryStrategyRaw == VisualHistoryStrategy.lastNFrames.rawValue {
                        Stepper(value: $viewModel.lastNFramesValue, in: 2...30) {
                            HStack {
                                Text("Window Size (N):")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.primaryText)
                                Text("\(viewModel.lastNFramesValue) frames")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.assembleBrandPrimary)
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    Text(visualStrategyDescription)
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.top, 2)
                }
                .padding(AppSpacing.md)
                
                Divider().padding(.horizontal, AppSpacing.md)
                
                NavigationLink(value: ProfileNavigationDestination.dataPrivacy) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.assembleBrandPrimary)
                        Text("View & Export Research Telemetry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.assembleBrandPrimary)
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
    
    private var cameraViewfinderSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("CAMERA & VIEWFINDER")
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
            Text("TACTILE & SENSORY")
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
    
    private var verificationModeDescription: String {
        switch viewModel.verificationMode {
        case "hybrid":
            return "Uses on-device Vision OCR + Foundation Models language explanation."
        case "vision":
            return "Deterministic Apple Vision feature extraction with structured templates."
        default:
            return "Predictable research demonstration script with simulated outcomes."
        }
    }
    
    private var visualStrategyDescription: String {
        switch viewModel.visualHistoryStrategyRaw {
        case VisualHistoryStrategy.currentFrame.rawValue:
            return "Strategy A: Baseline evaluates only the instantaneous current frame without prior visual context."
        case VisualHistoryStrategy.lastNFrames.rawValue:
            return "Strategy B: Maintains a sliding observation window of the most recent \(viewModel.lastNFramesValue) frames."
        case VisualHistoryStrategy.fullVisualHistory.rawValue:
            return "Strategy C: Preserves an unbounded chronological log of all session observations in context."
        case VisualHistoryStrategy.compressedStateHistory.rawValue:
            return "Strategy D: Compresses historical state into keyframe milestones with structured state summaries."
        default:
            return "Select a visual context strategy for comparative academic evaluation."
        }
    }
}

#Preview("App Settings View") {
    NavigationStack {
        AppSettingsView(viewModel: ProfileViewModel())
    }
}
