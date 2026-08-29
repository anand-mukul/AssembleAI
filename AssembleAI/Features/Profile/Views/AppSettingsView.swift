//
//  AppSettingsView.swift
//  AssembleAI
//

import SwiftUI

/// Application settings screen for configuring physical guidance details, camera features, verification engine modes, and haptics.
struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Section 1: Guidance & Verification Engine
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("PHYSICAL GUIDANCE & VERIFICATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
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
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                    )
                }
                
                // Section 2: Camera & Viewfinder Experience
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("CAMERA & VIEWFINDER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
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
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                    )
                }
                
                // Section 3: Tactile & Audio Feedback
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("TACTILE & SENSORY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
                    VStack(spacing: 0) {
                        Toggle(isOn: $viewModel.hapticsEnabled) {
                            Label("Haptic Guidance Feedback", systemImage: "waveform")
                                .font(.body)
                                .foregroundColor(AppColors.primaryText)
                        }
                        .padding(AppSpacing.md)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                    )
                }
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
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
}

#Preview("App Settings View") {
    NavigationStack {
        AppSettingsView(viewModel: ProfileViewModel())
    }
}
