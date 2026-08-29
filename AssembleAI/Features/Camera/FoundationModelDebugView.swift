//
//  FoundationModelDebugView.swift
//  AssembleAI
//

import SwiftUI

/// Development-only debug screen displaying Apple Foundation Models framework availability, prompt parameters, generation latency, and fallback status.
struct FoundationModelDebugView: View {
    let stepTitle: String
    let issueType: StateIssueType
    let expectedDesc: String
    let observedDesc: String
    let latencyMs: Int
    let usedFallback: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    BadgeView(text: "STATE REASONING ENGINE", color: .assembleBrandPrimary)
                    Spacer()
                    Text("\(latencyMs) ms")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.top, AppSpacing.sm)
                
                Text("Model Session Inspector")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                // Status Tiles
                HStack(spacing: AppSpacing.md) {
                    statusTile(title: "FRAMEWORK", value: isFrameworkAvailable ? "Available" : "Unavailable", color: isFrameworkAvailable ? AppColors.success : AppColors.warning)
                    statusTile(title: "FALLBACK", value: usedFallback ? "Active" : "None", color: usedFallback ? AppColors.warning : AppColors.success)
                    statusTile(title: "LATENCY", value: "\(latencyMs) ms", color: .assembleBrandPrimary)
                }
                
                // Input Prompt Context Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("INPUT CONTEXT (GROUNDED)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.secondaryText)
                    
                    debugRow(label: "Step", value: stepTitle)
                    debugRow(label: "Issue Type", value: issueType.rawValue)
                    debugRow(label: "Expected", value: expectedDesc)
                    debugRow(label: "Observed", value: observedDesc)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.secondaryGroupedBackground)
                )
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private var isFrameworkAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    private func statusTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryGroupedBackground)
        )
    }
    
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Foundation Model Debug View") {
    FoundationModelDebugView(
        stepTitle: "Attach 100uF Capacitor",
        issueType: .wrongConnection,
        expectedDesc: "GND Rail",
        observedDesc: "5V Rail",
        latencyMs: 124,
        usedFallback: false
    )
}
