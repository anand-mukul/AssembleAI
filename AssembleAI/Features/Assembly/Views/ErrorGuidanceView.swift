//
//  ErrorGuidanceView.swift
//  AssembleAI
//

import SwiftUI

/// Detailed troubleshooting guidance view explaining physical assembly mistakes and corrective actions.
struct ErrorGuidanceView: View {
    let stepOrder: Int
    let result: VerificationResult
    let onScanAgain: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header Badge
                HStack {
                    BadgeView(text: "STEP \(stepOrder) FIX", color: AppColors.error)
                    Spacer()
                }
                .padding(.top, AppSpacing.sm)
                
                // Title
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Let's fix this")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("The visual observer detected a placement mismatch. Follow the steps below to adjust your setup.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                // Expected vs Observed Diagram
                ExpectedVsObservedView(
                    expectedText: extractExpectedShort(result.expectedDescription),
                    observedText: extractObservedShort(result.detectedDescription)
                )
                
                // Remediation Instructions Card
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(AppColors.error)
                        Text("Action Required")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text(result.explanation)
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appCard(borderColor: AppColors.error.opacity(0.3))
                
                Spacer(minLength: AppSpacing.lg)
                
                PrimaryButton(title: "Scan Again", iconName: "camera") {
                    onScanAgain()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private func extractExpectedShort(_ full: String) -> String {
        if full.contains("Row 10 to Row 15") {
            return "Row 10 → Row 15"
        } else if full.contains("GND") {
            return "GND Rail"
        }
        return full
    }
    
    private func extractObservedShort(_ full: String) -> String {
        if full.contains("Row 10 to Row 14") {
            return "Row 10 → Row 14"
        } else if full.contains("5V") {
            return "5V Power Rail"
        }
        return full
    }
}

#Preview("Error Guidance View") {
    ErrorGuidanceView(
        stepOrder: 2,
        result: VerificationResult(
            status: .incorrect,
            confidence: 0.48,
            detectedDescription: "Resistor detected bridging Row 10 to Row 14",
            expectedDescription: "220Ω Resistor placed bridging Row 10 to Row 15",
            explanation: "The resistor lead is inserted into Row 14 instead of Row 15. Shift the right lead one slot over."
        ),
        onScanAgain: {}
    )
}
