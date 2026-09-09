//
//  ErrorGuidanceView.swift
//  AssembleAI
//

import SwiftUI

/// Detailed troubleshooting guidance view explaining physical assembly mistakes and corrective actions.
struct ErrorGuidanceView: View {
    let stepOrder: Int
    var stepTitle: String = "Assembly Step"
    var visualContract: VisualContract? = nil
    let result: VerificationResult
    let onScanAgain: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header Badge
                HStack {
                    BadgeView(text: "Step \(stepOrder) Correction", color: AppColors.badgeOrange)
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
                
                // Target Reference Blueprint Card
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        SemanticIconBadge(systemName: "photo.fill", tintColor: AppColors.badgeBlue)
                        Text("Target Blueprint Reference")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    StepIllustrationView(
                        stepOrder: stepOrder,
                        title: stepTitle,
                        visualContract: visualContract
                    )
                }
                
                // Remediation Instructions Card
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.xs) {
                        SemanticIconBadge(systemName: "wrench.and.screwdriver.fill", tintColor: AppColors.badgeOrange)
                        Text("Action Required")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text(result.explanation)
                        .font(.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appCard()
                
                Spacer(minLength: AppSpacing.lg)
                
                PrimaryButton(title: "Scan Again", iconName: "camera") {
                    onScanAgain()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
    }
    
    private func extractExpectedShort(_ full: String) -> String {
        cleanDescription(full)
    }
    
    private func extractObservedShort(_ full: String) -> String {
        cleanDescription(full)
    }
    
    private func cleanDescription(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: "part_dowel_8mm", with: "Wooden Dowels")
        clean = clean.replacingOccurrences(of: "part_cam_bolt", with: "Cam Bolts")
        clean = clean.replacingOccurrences(of: "part_cam_disc", with: "Cam Discs")
        clean = clean.replacingOccurrences(of: "part_shelf", with: "Shelf Board")
        clean = clean.replacingOccurrences(of: "part_side_panel", with: "Side Panel")
        clean = clean.replacingOccurrences(of: "part_back_panel", with: "Back Panel")
        clean = clean.replacingOccurrences(of: "part_nail_15mm", with: "Panel Pins")
        clean = clean.replacingOccurrences(of: "part_res_220", with: "220Ω Resistor")
        clean = clean.replacingOccurrences(of: "part_res_10k", with: "10kΩ Resistor")
        clean = clean.replacingOccurrences(of: "part_led_red", with: "Red LED")
        clean = clean.replacingOccurrences(of: "part_cap_100u", with: "100µF Capacitor")
        clean = clean.replacingOccurrences(of: "part_", with: "").replacingOccurrences(of: "_", with: " ")
        if clean.contains(" to ") {
            clean = clean.replacingOccurrences(of: " to ", with: " → ")
        }
        return clean
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
