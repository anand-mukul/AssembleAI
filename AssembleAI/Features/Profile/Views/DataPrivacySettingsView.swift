//
//  DataPrivacySettingsView.swift
//  AssembleAI
//
//  Data governance and on-device privacy screen managing cache clearance,
//  research telemetry export (Summary CSV, Events CSV, JSON), and SwiftData storage.
//

import SwiftUI
import SwiftData

/// Data governance and on-device privacy screen managing cache clearance, research CSV exports, and SwiftData storage.
struct DataPrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            GradientAtmosphereBackground(intensity: .subtle)
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Privacy Principle Card
                    privacyPrincipleCard
                    
                    // On-Device Storage Breakdown
                    storageBreakdownSection
                    
                    // Research Telemetry & Experiment Data Export
                    researchTelemetrySection
                    
                    // Danger Zone: Reset Local Data
                    managementSection
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isExportingTelemetry) {
            if let fileURL = viewModel.exportedShareURL {
                ShareSheet(activityItems: [fileURL])
            } else if !viewModel.exportedCSVContent.isEmpty {
                ShareSheet(activityItems: [viewModel.exportedCSVContent])
            }
        }
        .alert("Reset All Local Data?", isPresented: $viewModel.showResetDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                viewModel.resetAllLocalData(modelContext: modelContext)
            }
        } message: {
            Text("This will permanently delete your locally saved assembly attempts, sessions, and cached responses. This action cannot be undone.")
        }
        .alert("Clear Research Telemetry?", isPresented: $viewModel.showClearResearchAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Telemetry", role: .destructive) {
                viewModel.clearResearchData()
            }
        } message: {
            Text("This will permanently delete local research session benchmarks and event logs. Your assembly project progress and account data will not be affected.")
        }
        .overlay(alignment: .top) {
            if viewModel.showClearCacheToast {
                toastView(title: "Model cache cleared successfully", icon: "checkmark.circle.fill", color: AppColors.success)
            } else if viewModel.showResetSuccessToast {
                toastView(title: "All local data reset", icon: "trash.circle.fill", color: AppColors.warning)
            } else if viewModel.showClearResearchToast {
                toastView(title: "Research telemetry cleared", icon: "chart.line.uptrend.xyaxis.circle.fill", color: .assembleBrandPrimary)
            }
        }
        .task {
            await viewModel.loadResearchStats()
        }
    }
    
    // MARK: - Component Sections
    
    private var privacyPrincipleCard: some View {
        HStack(spacing: AppSpacing.md) {
            GradientIconBadge(
                iconName: "lock.shield.fill",
                size: 38,
                iconSize: 18,
                colors: [AppColors.success, AppColors.success.opacity(0.8)]
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text("On-Device Privacy Guaranteed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                Text("Camera frames and Vision OCR extractions are processed entirely on your device and never uploaded to external servers.")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .appCard(borderColor: AppColors.success.opacity(0.25))
    }
    
    private var storageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Storage & Cache")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
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
                
                Divider().opacity(0.3).padding(.horizontal, AppSpacing.md)
                
                storageRow(
                    icon: "internaldrive",
                    label: "Assembly Sessions",
                    detail: "\(viewModel.completedSessionsCount) local records",
                    actionTitle: nil,
                    action: nil
                )
            }
            .appCard(padding: 0)
        }
    }
    
    private var researchTelemetrySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("Assembly Telemetry & Logs")
                    .sectionHeaderStyle()
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Live Counter Pills
                HStack(spacing: AppSpacing.sm) {
                    telemetryPill(icon: "chart.bar.fill", title: "Sessions", count: "\(viewModel.researchSessionCount)")
                    telemetryPill(icon: "clock.arrow.circlepath", title: "Events", count: "\(viewModel.researchEventsCount)")
                    telemetryPill(icon: "memorychip", title: "Format", count: "RFC 4180")
                }
                
                Text("Export anonymized evaluation benchmarks comparing visual-history architectures. Outputs RFC 4180 CSVs structured for Excel, Python (pandas), R, or SPSS.")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                // Export Buttons Grid
                VStack(spacing: AppSpacing.sm) {
                    // Option 1: Session Summary CSV (Primary recommended for analysis)
                    exportOptionCard(
                        icon: "chart.bar.doc.horizontal.fill",
                        iconColors: [AppColors.iconBadgeGradientStart, AppColors.iconBadgeGradientEnd],
                        title: "Research Summary CSV",
                        subtitle: "1 row per session with 40 statistical columns",
                        badge: "Recommended",
                        isLoading: viewModel.isGeneratingExport
                    ) {
                        viewModel.exportSummaryCSV()
                    }
                    
                    // Option 2: Event Timeline CSV
                    exportOptionCard(
                        icon: "list.bullet.rectangle.fill",
                        iconColors: [AppColors.success, AppColors.success.opacity(0.8)],
                        title: "Detailed Event Timeline CSV",
                        subtitle: "All raw chronological events with millisecond latencies",
                        badge: nil,
                        isLoading: viewModel.isGeneratingExport
                    ) {
                        viewModel.exportDetailedEventsCSV()
                    }
                    
                    // Option 3: Raw JSON Dataset
                    exportOptionCard(
                        icon: "curlybraces",
                        iconColors: [Color.indigo, Color.indigo.opacity(0.8)],
                        title: "Structured Dataset JSON",
                        subtitle: "Machine-readable records for programmatic pipelines",
                        badge: nil,
                        isLoading: viewModel.isGeneratingExport
                    ) {
                        viewModel.exportJSONTelemetry()
                    }
                }
                .padding(.top, 2)
                
                // Clear Research Telemetry button
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.showClearResearchAlert = true
                    }) {
                        Label("Clear Research Logs", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .appCard()
        }
    }
    
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Reset Local Data")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            
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
            .appCard(borderColor: AppColors.error.opacity(0.3), padding: 0)
        }
    }
    
    // MARK: - Subcomponents
    
    private func telemetryPill(icon: String, title: String, count: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.assembleBrandPrimary)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppColors.secondaryText)
            Text(count)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.assembleBrandPrimary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
                )
        )
    }
    
    private func exportOptionCard(
        icon: String,
        iconColors: [Color],
        title: String,
        subtitle: String,
        badge: String?,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            HStack(spacing: AppSpacing.mdSm) {
                GradientIconBadge(
                    iconName: icon,
                    size: 38,
                    iconSize: 16,
                    colors: iconColors
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        
                        if let b = badge {
                            Text(b)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.assembleBrandPrimary))
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.assembleBrandPrimary)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColors.glassBorderUnified, lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)\(badge != nil ? ", \(badge!)" : "")")
        .accessibilityHint(isLoading ? "Currently generating export." : "Double tap to export data.")
    }
    
    private func storageRow(
        icon: String,
        label: String,
        detail: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            GradientIconBadge(iconName: icon, size: 30, iconSize: 14)
            
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
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }) {
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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(detail)")
        .accessibilityAction(named: actionTitle ?? "") {
            if let action = action {
                action()
            }
        }
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
                .fill(.ultraThinMaterial)
                .shadow(color: AppShadow.mediumColor, radius: 12, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.35), lineWidth: 0.5)
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
