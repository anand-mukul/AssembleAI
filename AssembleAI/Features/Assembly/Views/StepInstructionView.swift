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
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.badgeBlue)
                        .frame(width: 22, height: 22)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expected Result")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(expectedResultDescription)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .appCard()
                
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Text("Step \(stepOrder) of \(totalSteps)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.assembleBrandPrimary)
                        
                        Text("·")
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("\(Int((Double(stepOrder) / Double(max(1, totalSteps))) * 100))%")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(AppColors.tertiaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Cancel assembly session")
                }
                .padding(.leading, AppSpacing.screenEdge)
                .padding(.trailing, AppSpacing.screenEdge - 8)
                .frame(height: 44)
                
                // Edge-to-edge ambient progress rail spanning full screen width
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.borderSubtle.opacity(0.35))
                        
                        Rectangle()
                            .fill(Color.assembleBrandPrimary)
                            .frame(width: max(0, proxy.size.width * CGFloat(Double(stepOrder) / Double(max(1, totalSteps)))))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stepOrder)
                    }
                }
                .frame(height: 3)
            }
            .background(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onScanSetup()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 16, weight: .bold))
                        Text("Scan Setup")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AppColors.premiumButtonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppColors.premiumButtonBackground)
                            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .touchTarget()
                .accessibilityLabel("Scan setup with camera")
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColors.borderSubtle)
                    .frame(height: 0.5)
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
