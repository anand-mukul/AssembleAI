//
//  DataPrivacySettingsView.swift
//  AssembleAI
//

import SwiftUI
import SwiftData

/// Data governance and on-device privacy screen managing cache clearance, research CSV exports, and SwiftData storage.
struct DataPrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Privacy Principle Card
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundColor(AppColors.success)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("On-Device Privacy Guaranteed")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                        Text("Camera frames and Vision OCR extractions are processed entirely on your device and never uploaded to external servers.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.success.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.25), lineWidth: 1)
                )
                
                // On-Device Storage Breakdown
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("ON-DEVICE STORAGE & CACHE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
                    VStack(spacing: 0) {
                        storageRow(
                            icon: "cpu.fill",
                            label: "Optical Guidance Cache",
                            detail: "In-Memory LRU Cache",
                            actionTitle: "Clear",
                            action: {
                                viewModel.clearModelCache()
                            }
                        )
                        
                        Divider().padding(.horizontal, AppSpacing.md)
                        
                        storageRow(
                            icon: "internaldrive",
                            label: "Assembly Sessions",
                            detail: "\(viewModel.completedSessionsCount) local records",
                            actionTitle: nil,
                            action: nil
                        )
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
                
                // Research & Telemetry Export
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("RESEARCH TELEMETRY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Export anonymized, pseudonymous assembly timing and verification event records for empirical evaluation.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        PrimaryButton(title: "Export Research CSV", iconName: "square.and.arrow.up") {
                            viewModel.exportTelemetry()
                        }
                        .padding(.top, 4)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                    )
                }
                
                // Danger Zone: Reset Local Data
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("MANAGEMENT & RESET")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 4)
                        .tracking(1.0)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Button(action: {
                            viewModel.showResetDataAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(AppColors.error)
                                Text("Reset All Local Data & Sessions")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.error)
                                Spacer()
                            }
                            .padding(AppSpacing.md)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColors.error.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isExportingTelemetry) {
            ShareSheet(activityItems: [viewModel.exportedCSVContent])
        }
        .alert("Reset All Local Data?", isPresented: $viewModel.showResetDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                viewModel.resetAllLocalData(modelContext: modelContext)
            }
        } message: {
            Text("This will permanently delete your locally saved assembly attempts, sessions, and cached responses. This action cannot be undone.")
        }
        .overlay(alignment: .top) {
            if viewModel.showClearCacheToast {
                toastView(title: "Model cache cleared successfully", icon: "checkmark.circle.fill", color: AppColors.success)
            } else if viewModel.showResetSuccessToast {
                toastView(title: "All local data reset", icon: "trash.circle.fill", color: AppColors.warning)
            }
        }
    }
    
    private func storageRow(
        icon: String,
        label: String,
        detail: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.assembleBrandPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundColor(AppColors.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.assembleBrandPrimary.opacity(0.12))
                        )
                }
            }
        }
        .padding(AppSpacing.md)
    }
    
    private func toastView(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Capsule()
                .fill(AppColors.secondaryGroupedBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, AppSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview("Data & Privacy Settings") {
    NavigationStack {
        DataPrivacySettingsView(viewModel: ProfileViewModel())
    }
}
