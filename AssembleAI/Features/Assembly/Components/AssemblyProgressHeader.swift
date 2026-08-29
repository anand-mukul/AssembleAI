//
//  AssemblyProgressHeader.swift
//  AssembleAI
//

import SwiftUI

/// Compact step progress header displaying "Step X of Y" and subtle progress indicator.
struct AssemblyProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                Text("STEP \(currentStep) OF \(totalSteps)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.assembleBrandPrimary)
                    .tracking(1.0)
                
                Spacer()
                
                Text("\(Int((Double(currentStep) / Double(max(1, totalSteps))) * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            ProgressBar(
                value: Double(currentStep) / Double(max(1, totalSteps)),
                height: 4,
                fillColor: .assembleBrandPrimary
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}

#Preview("Assembly Progress Header") {
    AssemblyProgressHeader(currentStep: 3, totalSteps: 8)
        .padding()
}
