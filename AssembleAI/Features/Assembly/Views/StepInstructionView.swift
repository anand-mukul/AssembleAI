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
    var visualContract: VisualContract? = nil
    let onScanSetup: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Top Navigation Bar
                HStack {
                    AssemblyProgressHeader(currentStep: stepOrder, totalSteps: totalSteps)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.tertiaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
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
                StepIllustrationView(stepOrder: stepOrder, title: title, visualContract: visualContract)
                
                // Expected Result Callout
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        SemanticIconBadge(systemName: "info", tintColor: AppColors.badgeBlue)
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
        .background(AppColors.groupedBackground.ignoresSafeArea())
    }
    
    private var expectedResultDescription: String {
        if let contract = visualContract {
            if let pin = contract.pinPlacements.first {
                let toText = pin.toPin.label.isEmpty ? "" : " to pin \(pin.toPin.label)"
                let orient = contract.orientationConstraints.first.map { " (\($0.ruleDescription))" } ?? ""
                return "\(pin.partId) should connect from pin \(pin.fromPin.label)\(toText)\(orient)."
            }
            if let spatial = contract.spatialPlacements.first {
                let orient = contract.orientationConstraints.first.map { " (\($0.ruleDescription))" } ?? ""
                return "\(spatial.partId) placed at \(spatial.locationDescription)\(orient)."
            }
        }
        
        if !instruction.isEmpty {
            return instruction
        }
        
        return "Complete \(title) following the layout shown in the blueprint above."
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
