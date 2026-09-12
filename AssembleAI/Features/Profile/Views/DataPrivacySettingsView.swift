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
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isExportingTelemetry) {
            if let fileURL = viewModel.exportedShareURL {
                ShareSheet(activityItems: [fileURL])
            } else if !viewModel.exportedCSVContent.isEmpty {
                ShareSheet(activityItems: [viewModel.exportedCSVContent])
            }
        }
        .sheet(isPresented: $viewModel.showWebhookEditorSheet) {
            WebhookConfigurationSheet(viewModel: viewModel)
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
            } else if viewModel.showSyncSuccessToast {
                toastView(title: "Telemetry synced to cloud", icon: "icloud.and.arrow.up.fill", color: AppColors.success)
            }
        }
        .task {
            await viewModel.loadResearchStats()
        }
    }
    
    // MARK: - Component Sections
    
    private var privacyPrincipleCard: some View {
        HStack(spacing: AppSpacing.md) {
            SemanticIconBadge(
                iconName: "lock.shield.fill",
                size: 34,
                iconSize: 17,
                color: AppColors.badgeGreen
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text("On-Device Privacy Guaranteed")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText)
                Text("Camera frames and Vision OCR extractions are processed entirely on your device and never uploaded to external servers.")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineSpacing(2)
            }
        }
        .appCard()
    }
    
    private var storageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Storage & Cache")
                .standardSectionHeader()
            
            VStack(spacing: 0) {
                storageRow(
                    icon: "cpu.fill",
                    color: AppColors.badgeBlue,
                    label: "Optical Guidance Cache",
                    detail: "In-Memory LRU Cache",
                    actionTitle: "Clear",
                    action: {
                        viewModel.clearModelCache()
                    }
                )
                
                Divider().padding(.leading, AppSpacing.dividerLeadingInset)
                
                storageRow(
                    icon: "internaldrive",
                    color: AppColors.badgeGray,
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
            Text("Assembly Telemetry & Logs")
                .standardSectionHeader()
            
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Live Counter Pills
                HStack(spacing: AppSpacing.sm) {
                    telemetryPill(icon: "chart.bar.fill", title: "Sessions", count: "\(viewModel.researchSessionCount)")
                    telemetryPill(icon: "clock.arrow.circlepath", title: "Events", count: "\(viewModel.researchEventsCount)")
                    telemetryPill(icon: "memorychip", title: "Format", count: "RFC 4180")
                }
                
                // Automated Cloud Telemetry (Google Sheets / Webhook)
                cloudSyncCard
                
                // Export Buttons Grid
                VStack(spacing: AppSpacing.sm) {
                    exportOptionCard(
                        icon: "chart.bar.doc.horizontal.fill",
                        color: AppColors.badgeBlue,
                        title: "Research Summary CSV",
                        subtitle: "1 row per session with 40 statistical columns",
                        badge: "Recommended",
                        isLoading: viewModel.isGeneratingExport
                    ) {
                        viewModel.exportSummaryCSV()
                    }
                    
                    exportOptionCard(
                        icon: "list.bullet.rectangle.fill",
                        color: AppColors.badgeGreen,
                        title: "Detailed Event Timeline CSV",
                        subtitle: "All raw chronological events with millisecond latencies",
                        badge: nil,
                        isLoading: viewModel.isGeneratingExport
                    ) {
                        viewModel.exportDetailedEventsCSV()
                    }
                    
                    exportOptionCard(
                        icon: "curlybraces",
                        color: AppColors.badgeIndigo,
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
                .padding(.top, 2)
            }
            .appCard()
        }
    }
    
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Reset Local Data")
                .standardSectionHeader()
            
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
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.tertiaryBackground)
        )
    }
    
    private func exportOptionCard(
        icon: String,
        color: Color,
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
                SemanticIconBadge(
                    iconName: icon,
                    size: 32,
                    iconSize: 15,
                    color: color
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
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)\(badge != nil ? ", \(badge!)" : "")")
        .accessibilityHint(isLoading ? "Currently generating export." : "Double tap to export data.")
    }
    
    private func storageRow(
        icon: String,
        color: Color,
        label: String,
        detail: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: AppSpacing.mdSm) {
            SemanticIconBadge(iconName: icon, size: 30, iconSize: 15, color: color)
            
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
                .shadow(color: AppShadow.mediumColor, radius: 10, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .padding(.top, AppSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Automated Cloud Telemetry Card
    
    private var cloudSyncCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.mdSm) {
                SemanticIconBadge(
                    iconName: "icloud.and.arrow.up.fill",
                    size: 32,
                    iconSize: 16,
                    color: !viewModel.researchWebhookURL.isEmpty ? AppColors.badgeGreen : AppColors.badgeBlue
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Google Sheets / Cloud Sync")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        
                        if !viewModel.researchWebhookURL.isEmpty {
                            Text("Active")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.badgeGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.badgeGreen.opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            Text("Optional")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.tertiaryBackground)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(!viewModel.researchWebhookURL.isEmpty
                         ? "Session runs stream live into spreadsheet rows"
                         : "Stream benchmarks into Google Sheets for papers")
                        .font(.caption2)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.showWebhookEditorSheet = true
                }) {
                    Text(!viewModel.researchWebhookURL.isEmpty ? "Settings" : "Connect")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.assembleBrandPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.assembleBrandPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            if viewModel.pendingSyncCount > 0 {
                Divider()
                
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.warning)
                        Text("\(viewModel.pendingSyncCount) offline sessions pending")
                            .font(.caption2)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.flushCloudTelemetry()
                    }) {
                        if viewModel.isCloudSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Sync Now")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.assembleBrandPrimary)
                        }
                    }
                    .disabled(viewModel.isCloudSyncing)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Webhook Configuration Sheet

/// Modal sheet for entering a Google Apps Script Web App URL or Airtable webhook.
struct WebhookConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var webhookURLInput: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://script.google.com/macros/s/.../exec", text: $webhookURLInput)
                        .font(.subheadline)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                } header: {
                    Text("Webhook URL")
                } footer: {
                    Text("Paste your Google Apps Script Web App URL or Airtable webhook. Each completed assembly run automatically appends a row with all 25+ benchmark columns (latency, memory, tokens, accuracy) ready for LaTeX/Word tables.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Section {
                    Button(action: {
                        viewModel.testWebhookConnection(webhookURLInput)
                    }) {
                        HStack {
                            if viewModel.isTestingWebhook {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text("Testing Webhook Endpoint…")
                                    .foregroundColor(AppColors.secondaryText)
                            } else {
                                Image(systemName: "network")
                                    .foregroundColor(.assembleBrandPrimary)
                                Text("Test Webhook Connection")
                                    .fontWeight(.medium)
                                    .foregroundColor(.assembleBrandPrimary)
                            }
                            Spacer()
                        }
                    }
                    .disabled(webhookURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTestingWebhook)
                    
                    if let msg = viewModel.webhookTestStatusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.webhookTestSucceeded == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(viewModel.webhookTestSucceeded == true ? AppColors.badgeGreen : AppColors.error)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(viewModel.webhookTestSucceeded == true ? AppColors.badgeGreen : AppColors.error)
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Sends a lightweight verification ping to confirm your Google Apps Script or cloud webhook accepts JSON POST requests.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                if !viewModel.researchWebhookURL.isEmpty {
                    Section {
                        Button(role: .destructive, action: {
                            viewModel.saveWebhookURL("")
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text("Disconnect Webhook")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cloud Telemetry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveWebhookURL(webhookURLInput)
                        dismiss()
                    }
                }
            }
            .onAppear {
                webhookURLInput = viewModel.researchWebhookURL
            }
        }
    }
}

#Preview("Data & Privacy Settings") {
    NavigationStack {
        DataPrivacySettingsView(viewModel: ProfileViewModel())
    }
}
