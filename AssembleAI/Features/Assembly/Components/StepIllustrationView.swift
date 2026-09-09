//
//  StepIllustrationView.swift
//  AssembleAI
//

import SwiftUI

/// Vector blueprint illustration card representing hardware target expected state for an assembly step.
/// Dynamically adapts to electronics breadboards, physical furniture carpentry, and mechanical hardware domains.
struct StepIllustrationView: View {
    let stepOrder: Int
    let title: String
    var visualContract: VisualContract? = nil
    
    private var isPhysicalDomain: Bool {
        if let contract = visualContract {
            if contract.hasPhysicalConstraints && !contract.hasElectronicsConstraints {
                return true
            }
        }
        let lower = title.lowercased()
        return lower.contains("shelf") || lower.contains("panel") || lower.contains("dowel") ||
               lower.contains("cam") || lower.contains("screw") || lower.contains("bolt") ||
               lower.contains("wood") || lower.contains("furniture") || lower.contains("bracket")
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.secondaryGroupedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
                )
            
            VStack(spacing: AppSpacing.sm) {
                if isPhysicalDomain {
                    physicalBlueprintCanvas
                } else {
                    electronicsBreadboardCanvas
                }
                
                // Domain Blueprint Badge & Label
                HStack(spacing: 5) {
                    Image(systemName: isPhysicalDomain ? "wrench.and.screwdriver" : "cpu")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isPhysicalDomain ? "Physical Assembly Blueprint" : "Circuit Hardware Blueprint")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.secondaryText)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .frame(height: 180)
        .accessibilityHidden(true)
    }
    
    // MARK: - Physical / Carpentry Blueprint Canvas
    
    private var physicalBlueprintCanvas: some View {
        ZStack {
            // Blueprint workbench slate
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: 240, height: 116)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            // Drafting grid lines
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                }
            }
            .frame(width: 240)
            
            // Component schematic overlay
            physicalComponentOverlay
        }
    }
    
    @ViewBuilder
    private var physicalComponentOverlay: some View {
        let lower = title.lowercased()
        if lower.contains("dowel") || lower.contains("hole") {
            // Side Panel with Dowel Pins Schematic
            HStack(spacing: 16) {
                // Side panel board representation
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.brown.opacity(0.45))
                    .frame(width: 32, height: 84)
                    .overlay(
                        VStack(spacing: 18) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    )
                
                // Dowel pin alignment arrow & pin
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.assembleBrandPrimary)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.85, green: 0.72, blue: 0.52))
                            .frame(width: 28, height: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    Text("8mm Beech Dowel")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        } else if lower.contains("cam") || lower.contains("lock") {
            // Cam Lock Disc / Bolt Schematic
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.assembleBrandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cam Lock Fastener")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Rotate 180° clockwise")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        } else if lower.contains("shelf") || lower.contains("board") || lower.contains("panel") {
            // Shelf board placement schematic
            VStack(spacing: 6) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brown.opacity(0.4))
                        .frame(width: 14, height: 60)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.brown.opacity(0.7))
                        .frame(width: 120, height: 16)
                        .overlay(
                            Text("Shelf Board")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brown.opacity(0.4))
                        .frame(width: 14, height: 60)
                }
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.assembleBrandPrimary)
            }
        } else {
            // Generic physical hardware assembly schematic
            VStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.assembleBrandPrimary)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Electronics Breadboard Canvas
    
    private var electronicsBreadboardCanvas: some View {
        ZStack {
            // Breadboard Surface
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.tertiaryBackground)
                .frame(width: 220, height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                )
            
            // Pin Tie-Point Rows (dotted grid)
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
            
            // Circuit component overlay matching step title & contract
            electronicsComponentOverlay
        }
    }
    
    @ViewBuilder
    private var electronicsComponentOverlay: some View {
        let lower = title.lowercased()
        if lower.contains("resistor") || lower.contains("220") || lower.contains("10k") {
            // Resistor bridging Row 10 to Row 15
            ZStack {
                HStack(spacing: 50) {
                    Circle().stroke(Color.assembleBrandPrimary, lineWidth: 2).frame(width: 10, height: 10)
                    Circle().stroke(Color.assembleBrandPrimary, lineWidth: 2).frame(width: 10, height: 10)
                }
                
                HStack(spacing: 0) {
                    Rectangle().fill(Color.gray).frame(width: 20, height: 2)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 24, height: 10)
                        .overlay(
                            HStack(spacing: 3) {
                                Rectangle().fill(Color.red).frame(width: 2)
                                Rectangle().fill(Color.red).frame(width: 2)
                                Rectangle().fill(Color.brown).frame(width: 2)
                            }
                        )
                    Rectangle().fill(Color.gray).frame(width: 20, height: 2)
                }
            }
        } else if lower.contains("led") || lower.contains("diode") {
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
        } else if lower.contains("cap") || lower.contains("100u") {
            // Electrolytic Capacitor
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.75))
                    .frame(width: 18, height: 26)
                    .overlay(
                        Rectangle().fill(Color.white.opacity(0.7)).frame(width: 3, height: 26).offset(x: -6)
                    )
                HStack(spacing: 6) {
                    Rectangle().fill(Color.gray).frame(width: 2, height: 12)
                    Rectangle().fill(Color.gray).frame(width: 2, height: 16)
                }
            }
        } else if lower.contains("sensor") || lower.contains("temp") || lower.contains("ic") {
            // IC / Sensor chip
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.assembleBrandPrimary)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
            }
        } else {
            // Jumper wire or header fallback
            HStack(spacing: 8) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 24))
                    .foregroundColor(.assembleBrandPrimary)
                Text("Pin Header")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
            }
        }
    }
}

#Preview("Step Illustration View - Circuit") {
    StepIllustrationView(stepOrder: 1, title: "Place 220Ω Resistor")
        .padding()
}

#Preview("Step Illustration View - Furniture") {
    StepIllustrationView(stepOrder: 1, title: "Insert Dowels into Side Panels")
        .padding()
}
