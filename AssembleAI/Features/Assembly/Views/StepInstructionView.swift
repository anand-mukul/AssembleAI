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
        .safeAreaInset(edge: .top) {
            HStack {
                AssemblyProgressHeader(currentStep: stepOrder, totalSteps: totalSteps)
                
                Spacer()
                
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
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }
    
    private var expectedResultDescription: String {
        if let contract = visualContract {
            if let pin = contract.pinPlacements.first {
                let name = friendlyPartName(pin.partId)
                let toText = pin.toPin.label.isEmpty ? "" : " to pin \(pin.toPin.label)"
                let orient = contract.orientationConstraints.first.map { " (\($0.ruleDescription))" } ?? ""
                return "\(name) should connect from pin \(pin.fromPin.label)\(toText)\(orient)."
            }
            if let spatial = contract.spatialPlacements.first {
                let name = friendlyPartName(spatial.partId)
                let orient = contract.orientationConstraints.first.map { " (\($0.ruleDescription))" } ?? ""
                return "\(name) seated at \(spatial.locationDescription)\(orient)."
            }
        }
        
        if !instruction.isEmpty {
            return instruction
        }
        
        return "Complete \(title) following the layout shown in the blueprint above."
    }
    
    private func friendlyPartName(_ rawId: String) -> String {
        switch rawId {
        case "part_dowel_8mm": return "Wooden Dowel Pins"
        case "part_cam_bolt": return "Cam Lock Bolts"
        case "part_cam_disc": return "Cam Lock Discs"
        case "part_shelf": return "Shelf Board"
        case "part_side_panel": return "Side Panel"
        case "part_back_panel": return "HDF Back Panel"
        case "part_nail_15mm": return "15mm Panel Pins"
        case "part_res_220": return "220Ω Resistor"
        case "part_res_10k": return "10kΩ Resistor"
        case "part_led_red": return "Red LED"
        case "part_cap_100u": return "100µF Capacitor"
        default:
            return rawId.replacingOccurrences(of: "part_", with: "").replacingOccurrences(of: "_", with: " ").capitalized
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
