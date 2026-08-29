//
//  StepCompletedView.swift
//  AssembleAI
//

import SwiftUI
import UIKit

/// Step completion callout view presented after successful verification.
struct StepCompletedView: View {
    let stepOrder: Int
    let totalSteps: Int
    let result: VerificationResult
    let onNextStep: () -> Void
    
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(AppColors.success.opacity(0.25), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(iconScale)
                
                Circle()
                    .fill(AppColors.success.opacity(0.12))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(AppColors.success)
                    .scaleEffect(iconScale)
            }
            .frame(height: 160)
            
            VStack(spacing: AppSpacing.xs) {
                Text("Step Complete")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)
                
                Text(result.detectedDescription.isEmpty ? "Component placement verified." : result.detectedDescription)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            
            HStack(spacing: 6) {
                Text("\(stepOrder) of \(totalSteps) steps completed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.assembleBrandPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.assembleBrandPrimary.opacity(0.1))
            )
            
            Spacer()
            
            PrimaryButton(
                title: stepOrder >= totalSteps ? "Finish Assembly" : "Next Step",
                iconName: "arrow.right"
            ) {
                onNextStep()
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .background(AppColors.appBackground.ignoresSafeArea())
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                iconScale = 1.0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(stepOrder) of \(totalSteps) complete. \(result.detectedDescription). Next step button.")
    }
}

#Preview("Step Completed View") {
    StepCompletedView(
        stepOrder: 1,
        totalSteps: 8,
        result: VerificationResult(
            status: .correct,
            confidence: 0.94,
            detectedDescription: "220Ω Resistor placement verified.",
            expectedDescription: "220Ω Resistor placed",
            explanation: "Verified."
        ),
        onNextStep: {}
    )
}
