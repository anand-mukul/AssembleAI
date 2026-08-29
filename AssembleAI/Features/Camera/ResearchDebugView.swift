//
//  ResearchDebugView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Development-only research telemetry dashboard displaying session timing metrics, error rates, latencies, and CSV export.
struct ResearchDebugView: View {
    let sessionID: UUID
    
    @State private var metrics: ResearchSessionMetrics? = nil
    @State private var isExporting: Bool = false
    @State private var csvContent: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                HStack {
                    BadgeView(text: "RESEARCH INSTRUMENTATION", color: .blue)
                    Spacer()
                    Text(sessionID.uuidString.prefix(8).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
                
                Text("Session Evaluation Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                if let m = metrics {
                    // Primary Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                        metricCard(title: "SESSION DURATION", value: formatDuration(m.durationSeconds))
                        metricCard(title: "STEPS COMPLETED", value: "\(m.completedStepsCount)")
                        metricCard(title: "TOTAL ATTEMPTS", value: "\(m.totalAttempts)")
                        metricCard(title: "DETECTION ERRORS", value: "\(m.errorCount)", color: AppColors.error)
                        metricCard(title: "UNCERTAIN RATE", value: "\(m.uncertainCount)", color: AppColors.warning)
                        metricCard(title: "VERIFICATION LATENCY", value: "\(m.avgVerificationLatencyMs) ms", color: .indigo)
                    }
                    
                    // CSV Export Section
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("RESEARCH DATA EXPORT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("Export anonymized pseudonymous CSV log records for statistical evaluation.")
                            .font(.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        PrimaryButton(title: "Export Research CSV", iconName: "square.and.arrow.up") {
                            Task {
                                let csv = await ResearchLogger.shared.exportCSV()
                                self.csvContent = csv
                                self.isExporting = true
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.secondaryGroupedBackground)
                    )
                } else {
                    ProgressView()
                        .padding(.vertical, AppSpacing.xl)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .sheet(isPresented: $isExporting) {
            ShareSheet(activityItems: [csvContent])
        }
        .task {
            let computed = await ResearchLogger.shared.calculateMetrics(for: sessionID)
            self.metrics = computed
        }
    }
    
    private func metricCard(title: String, value: String, color: Color = AppColors.primaryText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
        )
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%dm %02ds", mins, secs)
    }
}

/// Helper wrapper presenting native UIActivityViewController share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Research Debug View") {
    ResearchDebugView(sessionID: UUID())
}
