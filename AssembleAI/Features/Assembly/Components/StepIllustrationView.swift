//
//  StepIllustrationView.swift
//  AssembleAI
//

import SwiftUI

/// Vector blueprint illustration card representing hardware target expected state for an assembly step.
struct StepIllustrationView: View {
    let stepOrder: Int
    let title: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.border.opacity(0.35), lineWidth: 1)
                )
            
            VStack(spacing: AppSpacing.sm) {
                // Solderless Breadboard Grid Diagram
                ZStack {
                    // Breadboard Surface
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.tertiaryBackground)
                        .frame(width: 220, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                        )
                    
                    // Pin Tie-Point Rows (Represented with dotted grid)
                    VStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 8) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Circle()
                                        .fill(AppColors.border.opacity(0.8))
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    }
                    
                    // Highlighted Component Overlay based on step order
                    illustrationOverlayForStep(stepOrder)
                }
                
                // Label
                Text("TARGET EXPECTED STATE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.0)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func illustrationOverlayForStep(_ step: Int) -> some View {
        switch step {
        case 1, 2:
            // Resistor bridging Row 10 to Row 15
            ZStack {
                // Highlighted slots
                HStack(spacing: 50) {
                    Circle().stroke(Color.assembleBrandPrimary, lineWidth: 2).frame(width: 10, height: 10)
                    Circle().stroke(Color.assembleBrandPrimary, lineWidth: 2).frame(width: 10, height: 10)
                }
                
                // Resistor Component Representation
                HStack(spacing: 0) {
                    Rectangle().fill(Color.gray).frame(width: 20, height: 2)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 24, height: 10)
                        .overlay(
                            HStack(spacing: 3) {
                                Rectangle().fill(Color.red).frame(width: 2)
                                Rectangle().fill(Color.purple).frame(width: 2)
                                Rectangle().fill(Color.brown).frame(width: 2)
                            }
                        )
                    Rectangle().fill(Color.gray).frame(width: 20, height: 2)
                }
            }
            
        case 3:
            // LED Component
            VStack(spacing: 0) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.warning)
                HStack(spacing: 6) {
                    Rectangle().fill(Color.gray).frame(width: 2, height: 16)
                    Rectangle().fill(Color.gray).frame(width: 2, height: 22)
                }
            }
            
        default:
            // Jumper Wire / IC
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.assembleBrandPrimary)
                Text("Pin Header")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
            }
        }
    }
}

#Preview("Step Illustration View") {
    StepIllustrationView(stepOrder: 1, title: "Place 220Ω Resistor")
        .padding()
}
