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
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(.assembleBrandPrimary)
                
                Spacer()
                
                Text("\(Int((Double(currentStep) / Double(max(1, totalSteps))) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
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
