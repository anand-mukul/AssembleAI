//
//  StepInstructionView.swift
//  AssembleAI
//

import SwiftUI

/// Pre-camera step instruction screen presenting detailed task instructions and expected state vector blueprint.
struct StepInstructionView: View {
    let stepOrder: Int
    let totalSteps: Int
    let title: String
    let instruction: String
    let onScanSetup: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Top Navigation Bar
                HStack {
                    AssemblyProgressHeader(currentStep: stepOrder, totalSteps: totalSteps)
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .accessibilityLabel("Cancel assembly session")
                }
                .padding(.top, AppSpacing.sm)
                
                // Step Title & Instruction
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    
                    if !instruction.isEmpty {
                        Text(instruction)
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Target Blueprint Illustration Card
                StepIllustrationView(stepOrder: stepOrder, title: title)
                
                // Expected Result Callout
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.assembleBrandPrimary)
                        Text("Expected Result")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text(expectedResultDescription)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appCard()
                
                Spacer(minLength: AppSpacing.lg)
                
                PrimaryButton(title: "Scan Setup", iconName: "viewfinder") {
                    onScanSetup()
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
        .background(AppColors.appBackground.ignoresSafeArea())
    }
    
    private var expectedResultDescription: String {
        switch stepOrder {
        case 1:
            return "The 220Ω resistor should bridge rows 10 and 15 on the breadboard with leads firmly inserted."
        case 2:
            return "The 100uF capacitor should bridge C2 header slots observing positive anode alignment."
        case 3:
            return "The LED anode lead (longer pin) must connect to Node 12A."
        default:
            return "Component placement should match the target blueprint layout shown above."
        }
    }
}

#Preview("Step Instruction View") {
    StepInstructionView(
        stepOrder: 1,
        totalSteps: 8,
        title: "Place the 220Ω resistor",
        instruction: "Place the 220Ω resistor between rows 10 and 15.",
        onScanSetup: {},
        onClose: {}
    )
}
